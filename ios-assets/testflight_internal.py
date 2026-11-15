"""Creates (or reuses) an internal TestFlight group for Mus'haf with access to every build, and adds the team's
App Store Connect users to it (the account holder first), so they can install builds from the TestFlight app at
once, without Beta App Review. Never prints anyone's email (the run logs are public).

Run by .github/workflows/testflight-internal.yml with the App Store Connect API key in the environment.
"""
import json
import sys
from pathlib import Path

from appstore_listing import Api, ApiError, rel

HERE = Path(__file__).resolve().parent
GROUP = 'Internal'


def main():
    bundle = json.loads((HERE / 'appstore-metadata' / 'listing.json').read_text())['common']['bundleId']
    api = Api()
    app = api.get('/v1/apps', **{'filter[bundleId]': bundle})['data'][0]
    groups = api.get(f"/v1/apps/{app['id']}/betaGroups", limit=50)['data']
    group = next((g for g in groups if g['attributes'].get('isInternalGroup')), None)
    if group:
        print(f"Internal group: {group['attributes']['name']} (exists)")
        if not group['attributes'].get('hasAccessToAllBuilds'):
            api.patch(f"/v1/betaGroups/{group['id']}", {'data': {'type': 'betaGroups', 'id': group['id'],
                                                                 'attributes': {'hasAccessToAllBuilds': True}}})
    else:
        group = api.post('/v1/betaGroups', {'data': {'type': 'betaGroups', 'attributes': {
            'name': GROUP, 'isInternalGroup': True, 'hasAccessToAllBuilds': True},
            'relationships': {'app': rel('apps', app['id'])}}})['data']
        print(f'Internal group: {GROUP} (created, with every build)')

    users = api.get('/v1/users', limit=100)['data']
    users.sort(key=lambda u: 'ACCOUNT_HOLDER' not in u['attributes'].get('roles', []))
    added = 0
    for u in users:
        a = u['attributes']
        who = ('the account holder' if 'ACCOUNT_HOLDER' in a.get('roles', []) else 'a team member')
        try:
            api.post('/v1/betaTesters', {'data': {'type': 'betaTesters', 'attributes': {
                'email': a['username'], 'firstName': a.get('firstName') or '', 'lastName': a.get('lastName') or ''},
                'relationships': {'betaGroups': {'data': [{'type': 'betaGroups', 'id': group['id']}]}}}})
            print(f'Added {who} ({a.get("firstName", "")})')
            added += 1
        except ApiError as e:
            msg = str(e).replace(a['username'], '<email>')
            print(f'{who}: {msg}')
    print(f'{added} tester(s) added. They get an email from TestFlight; the build is in the TestFlight app.')
    sys.exit(0 if added or users else 1)


if __name__ == '__main__':
    main()
