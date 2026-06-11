#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
oapi 동등성 검증 하니스 (replay + diff)

캡쳐된 코퍼스(corpus.jsonl)의 요청을 신규 open-api 서비스로 replay 하고,
응답을 "캡쳐된 응답"과 정규화 비교한다.

핵심 전제:
  - guarantee-analysis 는 입력(마이데이터 보험 포트폴리오)이 요청 body 안에 통째로 담겨 오므로
    분석 결과는 요청의 순수 함수다 → 같은 요청을 재생하면 캡쳐 응답이 결정론적으로 재현된다.
  - 따라서 "신규 vs 캡쳐응답" 비교로 충분하고, 레거시(8105)를 다시 때리지 않아 부작용을 피한다.

안전 기본값:
  - 기본은 dry-run (실제 전송 안 함). 실제 전송은 --send 필요.
  - withdrawal(파괴적)은 --include-withdrawal + 테스트 uid 일 때만.
  - 사무실 IP 에서 실행해야 신규 서비스(office-IP 한정 룰)에 도달한다.

stdlib only (requests 미사용).

사용 예:
  # dry-run (무엇을 보낼지만 확인)
  python3 oapi_replay_diff.py --corpus /tmp/oapi-corpus/corpus.jsonl --target https://oapi.bomapp.co.kr
  # 실제 검증 (토큰 자동 발급) — 반드시 사무실 IP에서 실행 (office IP 룰이 oapi→신규로 라우팅)
  python3 oapi_replay_diff.py --corpus ... --target https://oapi.bomapp.co.kr --send \
      --client-id <id> --client-secret <secret>
"""
import argparse, json, sys, re, ssl, urllib.request, urllib.error, urllib.parse
from collections import defaultdict

# ── 정규화: 비휘발성 비교를 위해 마스킹할 키(소문자) 및 값 패턴 ─────────────
VOLATILE_KEYS = {
    'resultexpiredate', 'transactionno', 'timestamp', 'reporttime', 'date',
    'createdat', 'updatedat', 'regdate', 'accesstoken', 'token', 'refreshtoken',
    'expiresin', 'expireat', 'expiredate', 'requestid', 'traceid', 'txid',
}
DATEISH = re.compile(r'^\d{4}-?\d{2}-?\d{2}([ T]\d{2}:\d{2}.*)?$')
JWTISH = re.compile(r'^[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+$')

# @OpenV3TokenRequired / @OpenTokenRequired 가 붙는(=Authorization 필요한) 경로
TOKEN_REQUIRED = (
    '/api/external/v1/insurance/guarantee-analysis',
    '/api/external/v1/insurance/withdrawal',
    '/v4/guarantees', '/v4/withdrawal', '/v4/consultation/cancel',
)
# 전송 시 제거할 헤더 (클라이언트/ALB 가 재설정)
DROP_HEADERS = {
    'host', 'content-length', 'x-amzn-trace-id', 'connection', 'accept-encoding',
    'x-forwarded-for', 'x-forwarded-port', 'x-forwarded-proto', 'x-j_http_tuid_',
}


def flat_headers(h):
    """logbook 헤더는 값이 리스트(['application/json'])일 수 있음 → 평탄화."""
    out = {}
    for k, v in (h or {}).items():
        if isinstance(v, list):
            v = v[0] if v else ''
        out[k] = v
    return out


def normalize(o):
    """volatile 키/값을 마스킹해 비휘발성 구조만 남긴다."""
    if isinstance(o, dict):
        r = {}
        for k, v in o.items():
            r[k] = '<masked>' if k.lower() in VOLATILE_KEYS else normalize(v)
        return r
    if isinstance(o, list):
        return [normalize(x) for x in o]
    if isinstance(o, str):
        if DATEISH.match(o) or JWTISH.match(o):
            return '<masked>'
        return o
    return o


def deep_diff(a, b, path='$'):
    """정규화된 두 객체의 구조적 차이 경로 목록."""
    diffs = []
    if type(a) is not type(b):
        return [f'{path}: type {type(a).__name__} != {type(b).__name__}']
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                diffs.append(f'{path}.{k}: actual 에 없음')
            elif k not in b:
                diffs.append(f'{path}.{k}: captured 에 없음')
            else:
                diffs += deep_diff(a[k], b[k], f'{path}.{k}')
    elif isinstance(a, list):
        if len(a) != len(b):
            diffs.append(f'{path}: 길이 {len(a)} != {len(b)}')
        else:
            for i, (x, y) in enumerate(zip(a, b)):
                diffs += deep_diff(x, y, f'{path}[{i}]')
    else:
        if a != b:
            diffs.append(f'{path}: {a!r} != {b!r}')
    return diffs


def parse_json(s):
    if isinstance(s, (dict, list)):
        return s
    if s is None:
        return None
    try:
        return json.loads(s)
    except Exception:
        return s


def send(url, method, headers, body_bytes, insecure=False, timeout=30):
    ctx = ssl.create_default_context()
    if insecure:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url, data=body_bytes, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
            return r.status, r.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', 'replace')
    except Exception as e:
        return None, f'ERROR: {e}'


def mint_token(target, cid, secret, insecure):
    """oauth-token 으로 신규 토큰 발급. 발급 응답에서 토큰 필드를 추정 추출."""
    body = json.dumps({'clientId': cid, 'clientSecret': secret}).encode()
    st, bd = send(target.rstrip('/') + '/api/external/v1/oauth-token', 'POST',
                  {'Content-Type': 'application/json'}, body, insecure)
    if st != 200:
        return None
    j = parse_json(bd)
    cands = [j]
    if isinstance(j, dict) and isinstance(j.get('data'), dict):
        cands.append(j['data'])
    for d in cands:
        if isinstance(d, dict):
            for k in ('accessToken', 'access_token', 'token'):
                if d.get(k):
                    return d[k]
    return None


def main():
    ap = argparse.ArgumentParser(description='oapi 동등성 검증 (replay + diff)')
    ap.add_argument('--corpus', required=True, help='corpus.jsonl 경로')
    ap.add_argument('--target', required=True, help='신규 서비스 base URL (예: https://oapi.bomapp.co.kr)')
    ap.add_argument('--report', default='/tmp/oapi-corpus/diff-report.jsonl')
    ap.add_argument('--send', action='store_true', help='실제 전송 (미지정 시 dry-run)')
    ap.add_argument('--client-id', help='토큰 발급용 clientId')
    ap.add_argument('--client-secret', help='토큰 발급용 clientSecret')
    ap.add_argument('--auth-scheme', default='Bearer', help='Authorization 접두 (Bearer 또는 빈값)')
    ap.add_argument('--include-withdrawal', action='store_true', help='withdrawal(파괴적) 포함 — 테스트 uid 전용')
    ap.add_argument('--insecure', action='store_true', help='TLS 검증 생략')
    a = ap.parse_args()

    recs = [json.loads(l) for l in open(a.corpus, encoding='utf-8') if l.strip()]
    token = None
    if a.send and a.client_id and a.client_secret:
        token = mint_token(a.target, a.client_id, a.client_secret, a.insecure)
        print('토큰 발급:', 'OK' if token else 'FAILED', file=sys.stderr)

    out = open(a.report, 'w', encoding='utf-8')
    summ = defaultdict(lambda: [0, 0])  # path -> [total, match]
    skipped = defaultdict(int)

    for rec in recs:
        path = rec['path']
        if path.endswith('/withdrawal') and not a.include_withdrawal:
            skipped[path] += 1
            continue

        uri = rec.get('uri') or path
        parts = urllib.parse.urlsplit(uri)
        url = a.target.rstrip('/') + parts.path + (('?' + parts.query) if parts.query else '')

        hdr = {k: v for k, v in flat_headers(rec.get('headers')).items()
               if k.lower() not in DROP_HEADERS}
        if any(path.startswith(p) for p in TOKEN_REQUIRED) and token:
            hdr['Authorization'] = (a.auth_scheme + ' ' + token).strip() if a.auth_scheme else token
        hdr.setdefault('Content-Type', 'application/json')

        body = rec.get('body')
        body_bytes = (json.dumps(body, ensure_ascii=False).encode()
                      if isinstance(body, (dict, list)) else (body or '').encode())

        result = {'path': path, 'method': rec['method']}

        if not a.send:
            result.update({'dry_run': True, 'url': url, 'header_keys': sorted(hdr),
                           'token_required': any(path.startswith(p) for p in TOKEN_REQUIRED)})
            out.write(json.dumps(result, ensure_ascii=False) + '\n')
            summ[path][0] += 1
            continue

        st, bd = send(url, rec['method'], hdr, body_bytes, a.insecure)
        cap_status = rec.get('resp_status')
        diffs = deep_diff(normalize(parse_json(bd)), normalize(parse_json(rec.get('resp_body'))))
        ok = (st == cap_status) and not diffs
        summ[path][0] += 1
        summ[path][1] += 1 if ok else 0
        result.update({'status_actual': st, 'status_captured': cap_status,
                       'match': ok, 'diff_count': len(diffs), 'diffs': diffs[:25]})
        out.write(json.dumps(result, ensure_ascii=False) + '\n')

    out.close()
    print('\n=== 동등성 결과 (match/total) ===')
    total_t = total_m = 0
    for p, (t, m) in sorted(summ.items()):
        print(f'  {m}/{t}  {p}')
        total_t += t
        total_m += m
    for p, n in skipped.items():
        print(f'  (skip {n})  {p}  — withdrawal 제외 (--include-withdrawal + 테스트 uid 로만)')
    if a.send:
        print(f'\n전체: {total_m}/{total_t} 일치 → {"PASS" if total_m == total_t and total_t else "FAIL (리포트 확인)"}')
    else:
        print(f'\n[dry-run] {total_t} 건 전송 예정 (실제 검증은 --send)')
    print('리포트:', a.report)


if __name__ == '__main__':
    main()
