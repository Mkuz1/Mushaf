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
    print(f'{added} tester(s) added.')

    # The latest builds: in the group, and their internal-testing state.
    builds = api.get('/v1/builds', **{'filter[app]': app['id'], 'sort': '-uploadedDate', 'limit': 3,
                                       'include': 'buildBetaDetail'})
    details = {d['id']: d['attributes'] for d in builds.get('included', []) if d['type'] == 'buildBetaDetails'}
    for b in builds['data']:
        d = details.get(b['relationships']['buildBetaDetail']['data']['id'], {})
        print(f"Build {b['attributes']['version']}: {b['attributes'].get('processingState')}, "
              f"expired={b['attributes'].get('expired')}, internal={d.get('internalBuildState')}, "
              f"external={d.get('externalBuildState')}, "
              f"encryption answered={b['attributes'].get('usesNonExemptEncryption')}")
        try:
            api.post(f"/v1/betaGroups/{group['id']}/relationships/builds",
                     {'data': [{'type': 'builds', 'id': b['id']}]})
            print('   added to the internal group')
        except ApiError as e:
            print(f'   adding to the group: {e}')
        if b['attributes'].get('usesNonExemptEncryption') is None:
            try:
                api.patch(f"/v1/builds/{b['id']}", {'data': {'type': 'builds', 'id': b['id'],
                                                             'attributes': {'usesNonExemptEncryption': False}}})
                print('   encryption question answered: no')
            except ApiError as e:
                print(f'   encryption question: {e}')

    # The testers: their state, and a new invitation.
    for t in api.get(f"/v1/betaGroups/{group['id']}/betaTesters", limit=50)['data']:
        a = t['attributes']
        print(f"Tester {a.get('firstName', '')}: invite {a.get('inviteType')}, state {a.get('state')}")
        try:
            api.post('/v1/betaTesterInvitations', {'data': {'type': 'betaTesterInvitations', 'relationships': {
                'app': rel('apps', app['id']), 'betaTester': rel('betaTesters', t['id'])}}})
            print('   invitation sent again')
        except ApiError as e:
            print(f"   invitation: {str(e).replace(a.get('email') or '@@', '<email>')}")
    sys.exit(0)


if __name__ == '__main__':
    main()
