"""Publishes Mushaf on Google Play through the Play Developer API: uploads the app bundle to a track (production by
default) with its release notes, sets the store title and replaces the icon, feature graphic and Android TV banner
in every store listing language, then commits, which sends the changes to Google's review. Settings:
play-release.json.

Run by .github/workflows/play-publish.yml, with the service account key (JSON) in PLAY_SERVICE_ACCOUNT_JSON.
"""
import argparse
import json
import os
import sys
from pathlib import Path

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

HERE = Path(__file__).resolve().parent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--aab', help='the app bundle to release (omit to update the store listing only)')
    ap.add_argument('--version-name', default='')
    ap.add_argument('--track', default='production')
    ap.add_argument('--rollout', type=float, default=1.0, help='fraction of users (1 = everyone)')
    args = ap.parse_args()
    cfg = json.loads((HERE / 'play-release.json').read_text())
    pkg = cfg['package']
    api = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{pkg}'
    upload = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{pkg}'

    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']), scopes=['https://www.googleapis.com/auth/androidpublisher'])
    creds.refresh(Request())

    def call(method, url, **kw):
        headers = {'Authorization': f'Bearer {creds.token}', **kw.pop('headers', {})}
        r = requests.request(method, url, headers=headers, timeout=900, **kw)
        if r.status_code >= 400:
            sys.exit(f"{method} {url.split(pkg)[-1]} -> {r.status_code}: {r.text[:1500]}")
        return r.json() if r.content else {}

    edit = call('POST', f'{api}/edits')['id']
    print(f'Edit opened for {pkg}')

    if args.aab:
        with open(args.aab, 'rb') as f:
            bundle = call('POST', f'{upload}/edits/{edit}/bundles?uploadType=media', data=f,
                          headers={'Content-Type': 'application/octet-stream'})
        code = bundle['versionCode']
        print(f'Bundle uploaded: version code {code}')
        release = {'name': args.version_name or str(code), 'versionCodes': [str(code)],
                   'releaseNotes': [{'language': l, 'text': t} for l, t in cfg['releaseNotes'].items()]}
        if args.rollout < 1:
            release.update(status='inProgress', userFraction=args.rollout)
        else:
            release['status'] = 'completed'
        call('PUT', f'{api}/edits/{edit}/tracks/{args.track}', json={'track': args.track, 'releases': [release]})
        print(f"Track {args.track}: release {release['name']} ({release['status']}"
              + (f", {args.rollout:.0%} of users" if args.rollout < 1 else '') + ')')

    listings = call('GET', f'{api}/edits/{edit}/listings').get('listings', [])
    for listing in listings:
        lang = listing['language']
        call('PATCH', f'{api}/edits/{edit}/listings/{lang}', json={'title': cfg['title']})
        for kind, file in cfg['images'].items():
            path = HERE / file
            call('DELETE', f'{api}/edits/{edit}/listings/{lang}/{kind}')
            with open(path, 'rb') as f:
                call('POST', f'{upload}/edits/{edit}/listings/{lang}/{kind}?uploadType=media', data=f,
                     headers={'Content-Type': 'image/png'})
        print(f"Listing {lang}: title \"{cfg['title']}\", {', '.join(cfg['images'])} replaced")

    call('POST', f'{api}/edits/{edit}:commit')
    print('Committed: sent to Google Play for review.')


if __name__ == '__main__':
    main()
