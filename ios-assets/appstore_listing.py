"""Fills Mus'haf's App Store listing through the App Store Connect API, from appstore-metadata/listing.json and
the screenshots in appstore-assets/: names, subtitles, descriptions, keywords and URLs in Arabic, English and
French, categories, age rating, price (free), the version and its build, screenshots for every device, and the
App Review notes. With --submit it also submits the version for review.

Run by .github/workflows/appstore-listing.yml, with the API key in the environment:
APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_KEY (the .p8 contents). Never prints the key.

Every part is attempted even when another fails; Apple's error for each failure is printed, and the exit code
is non-zero if anything failed.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path

import jwt
import requests

API = 'https://api.appstoreconnect.apple.com'
HERE = Path(__file__).resolve().parent
failures = []


def token():
    now = int(time.time())
    return jwt.encode(
        {'iss': os.environ['APPSTORE_ISSUER_ID'], 'iat': now, 'exp': now + 15 * 60, 'aud': 'appstoreconnect-v1'},
        os.environ['APPSTORE_KEY'], algorithm='ES256', headers={'kid': os.environ['APPSTORE_KEY_ID'], 'typ': 'JWT'})


class Api:
    def __init__(self):
        self.s = requests.Session()
        self.t, self.made = None, 0

    def call(self, method, path, body=None, params=None):
        if time.time() - self.made > 600:
            self.t, self.made = token(), time.time()
        r = self.s.request(method, API + path, json=body, params=params,
                           headers={'Authorization': f'Bearer {self.t}'}, timeout=120)
        if r.status_code >= 400:
            raise ApiError(method, path, r)
        return r.json() if r.content else {}

    def get(self, path, **params):
        return self.call('GET', path, params=params or None)

    def post(self, path, body):
        return self.call('POST', path, body)

    def patch(self, path, body):
        return self.call('PATCH', path, body)

    def delete(self, path):
        return self.call('DELETE', path)


class ApiError(Exception):
    def __init__(self, method, path, r):
        try:
            errs = r.json().get('errors', [])
            detail = '; '.join(f"{e.get('title')}: {e.get('detail')}" for e in errs) or r.text[:500]
        except ValueError:
            detail = r.text[:500]
        super().__init__(f'{method} {path} -> {r.status_code}: {detail}')


def step(name):
    def wrap(fn):
        def run(*a, **k):
            print(f'\n== {name}', flush=True)
            try:
                return fn(*a, **k)
            except Exception as e:  # keep going: report everything in one run
                print(f'   FAILED: {e}', flush=True)
                failures.append(f'{name}: {e}')
        return run
    return wrap


def rel(type_, id_):
    return {'data': {'type': type_, 'id': id_}}


# ---------------------------------------------------------------------------------------------------------------


@step('App')
def find_app(api, bundle):
    apps = api.get('/v1/apps', **{'filter[bundleId]': bundle})['data']
    if not apps:
        raise RuntimeError(f'no app with bundle ID {bundle} in App Store Connect (create it first)')
    app = apps[0]
    print(f"   {app['attributes']['name']} ({app['id']}), primary language {app['attributes'].get('primaryLocale')}")
    return app


@step('App information: names, subtitles, privacy policy, categories')
def app_info(api, app, cfg, meta):
    infos = api.get(f"/v1/apps/{app['id']}/appInfos")['data']
    # The editable one (the other, if any, is the live version's).
    info = next((i for i in infos if i['attributes'].get('appStoreState') != 'READY_FOR_SALE'
                 and i['attributes'].get('state') != 'READY_FOR_DISTRIBUTION'), infos[0])
    existing = {l['attributes']['locale']: l for l in
                api.get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")['data']}
    for lang, locale in cfg['locales'].items():
        attrs = {'name': meta[lang]['name'], 'subtitle': meta[lang]['subtitle'],
                 'privacyPolicyUrl': cfg['privacyPolicyUrl']}
        try:
            if locale in existing:
                api.patch(f"/v1/appInfoLocalizations/{existing[locale]['id']}",
                          {'data': {'type': 'appInfoLocalizations', 'id': existing[locale]['id'], 'attributes': attrs}})
            else:
                api.post('/v1/appInfoLocalizations',
                         {'data': {'type': 'appInfoLocalizations', 'attributes': {'locale': locale, **attrs},
                                   'relationships': {'appInfo': rel('appInfos', info['id'])}}})
            print(f'   {locale}: {attrs["name"]} — {attrs["subtitle"]}')
        except ApiError as e:
            print(f'   {locale} FAILED: {e}')
            failures.append(f'app info {locale}: {e}')
    api.patch(f"/v1/appInfos/{info['id']}", {'data': {'type': 'appInfos', 'id': info['id'], 'relationships': {
        'primaryCategory': rel('appCategories', cfg['primaryCategory']),
        'secondaryCategory': rel('appCategories', cfg['secondaryCategory'])}}})
    print(f"   categories: {cfg['primaryCategory']}, {cfg['secondaryCategory']}")
    return info


@step('Age rating (4+: none of the content)')
def age_rating(api, info):
    decl = api.get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")['data']
    have = decl['attributes']
    attrs = {k: 'NONE' for k in AGE_LEVELS if k in have}
    attrs.update({k: False for k in AGE_NO})
    for _ in range(10):
        try:
            api.patch(f"/v1/ageRatingDeclarations/{decl['id']}",
                      {'data': {'type': 'ageRatingDeclarations', 'id': decl['id'], 'attributes': attrs}})
            break
        except ApiError as e:
            # A question added since: Apple names it ("provide a value for the attribute 'x'"); answer no.
            m = re.search(r"value for the attribute '(\w+)'", str(e))
            if not m or m.group(1) in attrs:
                raise
            attrs[m.group(1)] = False
            print(f'   also answering {m.group(1)}: no')
    print(f'   {len(attrs)} answers set to none/no')


AGE_LEVELS = ('alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated', 'gunsOrOtherWeapons',
              'horrorOrFearThemes', 'matureOrSuggestiveThemes', 'medicalOrTreatmentInformation',
              'profanityOrCrudeHumor', 'sexualContentGraphicAndNudity', 'sexualContentOrNudity',
              'violenceCartoonOrFantasy', 'violenceRealistic', 'violenceRealisticProlongedGraphicOrSadistic')
AGE_NO = ('gambling', 'unrestrictedWebAccess', 'lootBox', 'messagingAndChat', 'parentalControls', 'ageAssurance',
          'userGeneratedContent', 'advertising', 'healthOrWellnessTopics', 'socialMedia')


@step('Price: free')
def price(api, app):
    points = api.get(f"/v1/apps/{app['id']}/appPricePoints",
                     **{'filter[territory]': 'USA', 'limit': 200})['data']
    free = next(p for p in points if float(p['attributes']['customerPrice']) == 0)
    api.post('/v1/appPriceSchedules', {
        'data': {'type': 'appPriceSchedules', 'relationships': {
            'app': rel('apps', app['id']),
            'baseTerritory': rel('territories', 'USA'),
            'manualPrices': {'data': [{'type': 'appPrices', 'id': '${free}'}]}}},
        'included': [{'type': 'appPrices', 'id': '${free}', 'attributes': {'startDate': None},
                      'relationships': {'appPricePoint': rel('appPricePoints', free['id'])}}]})
    print('   free, in every territory (base: United States)')


@step('Version')
def version(api, app, cfg):
    versions = api.get(f"/v1/apps/{app['id']}/appStoreVersions", **{'filter[platform]': 'IOS', 'limit': 20})['data']
    editable = [v for v in versions if v['attributes']['appStoreState'] in
                ('PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED')]
    if editable:
        v = editable[0]
    else:
        v = api.post('/v1/appStoreVersions', {'data': {'type': 'appStoreVersions', 'attributes': {
            'platform': 'IOS', 'versionString': cfg['version']}, 'relationships': {'app': rel('apps', app['id'])}}})['data']
    attrs = {'versionString': cfg['version'], 'releaseType': 'AFTER_APPROVAL'}
    if cfg.get('copyright'):
        attrs['copyright'] = cfg['copyright']
    api.patch(f"/v1/appStoreVersions/{v['id']}", {'data': {'type': 'appStoreVersions', 'id': v['id'], 'attributes': attrs}})
    print(f"   {cfg['version']} ({v['attributes']['appStoreState']}), released when approved")
    return v


@step('Version texts: description, keywords, promotional text, URLs')
def version_texts(api, ver, cfg, meta, first_version):
    existing = {l['attributes']['locale']: l for l in
                api.get(f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")['data']}
    out = {}
    for lang, locale in cfg['locales'].items():
        attrs = {'description': meta[lang]['description'], 'keywords': meta[lang]['keywords'],
                 'promotionalText': meta[lang]['promotionalText'],
                 'supportUrl': cfg['supportUrl'], 'marketingUrl': cfg['marketingUrl']}
        if not first_version:
            attrs['whatsNew'] = meta[lang]['whatsNew']
        try:
            if locale in existing:
                loc = api.patch(f"/v1/appStoreVersionLocalizations/{existing[locale]['id']}",
                                {'data': {'type': 'appStoreVersionLocalizations', 'id': existing[locale]['id'],
                                          'attributes': attrs}})['data']
            else:
                loc = api.post('/v1/appStoreVersionLocalizations',
                               {'data': {'type': 'appStoreVersionLocalizations', 'attributes': {'locale': locale, **attrs},
                                         'relationships': {'appStoreVersion': rel('appStoreVersions', ver['id'])}}})['data']
            out[lang] = loc
            print(f'   {locale}: done')
        except ApiError as e:
            print(f'   {locale} FAILED: {e}')
            failures.append(f'version texts {locale}: {e}')
    return out


@step('Build')
def attach_build(api, app, ver, cfg):
    builds = api.get('/v1/builds', **{'filter[app]': app['id'], 'filter[version]': cfg['build'],
                                       'filter[preReleaseVersion.platform]': 'IOS', 'limit': 5})['data']
    if not builds:
        raise RuntimeError(f"build {cfg['build']} isn't in App Store Connect yet (still processing?)")
    b = builds[0]
    state = b['attributes'].get('processingState')
    if state != 'VALID':
        raise RuntimeError(f"build {cfg['build']} is {state} (wait for Apple to finish processing it)")
    api.patch(f"/v1/appStoreVersions/{ver['id']}/relationships/build", rel('builds', b['id']))
    print(f"   build {cfg['build']} attached")


# Screenshot folders, and the display type App Store Connect files them under (tried in order).
# iPhone Duo has one display type for both screens: the unfolded shots first, then the folded ones (10 at most).
SHOTS = [
    (['iphone-6.9'], ['APP_IPHONE_67']),
    (['ipad-13'], ['APP_IPAD_PRO_3GEN_129']),
    (['iphone-duo-inner', 'iphone-duo-outer'], ['APP_IPHONE_DUO']),
]


def upload_shot(api, set_id, path):
    data = path.read_bytes()
    shot = api.post('/v1/appScreenshots', {'data': {'type': 'appScreenshots', 'attributes': {
        'fileName': path.name, 'fileSize': len(data)},
        'relationships': {'appScreenshotSet': rel('appScreenshotSets', set_id)}}})['data']
    for op in shot['attributes']['uploadOperations']:
        part = data[op['offset']:op['offset'] + op['length']]
        headers = {h['name']: h['value'] for h in op.get('requestHeaders', [])}
        r = requests.request(op['method'], op['url'], data=part, headers=headers, timeout=300)
        r.raise_for_status()
    api.patch(f"/v1/appScreenshots/{shot['id']}", {'data': {'type': 'appScreenshots', 'id': shot['id'], 'attributes': {
        'uploaded': True, 'sourceFileChecksum': hashlib.md5(data).hexdigest()}}})
    return shot['id']


@step('Screenshots')
def screenshots(api, locs, cfg):
    root = HERE / 'appstore-assets'
    uploaded = []
    for lang, loc in locs.items():
        sets = {s['attributes']['screenshotDisplayType']: s for s in
                api.get(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets", limit=50)['data']}
        for folders, types in SHOTS:
            folder = ' + '.join(folders)
            files = [f for d in folders for f in sorted((root / d / lang).glob('*.png'))][:10]
            if not files:
                continue
            done = False
            for display in types:
                try:
                    if display in sets:
                        s = sets[display]
                        for old in api.get(f"/v1/appScreenshotSets/{s['id']}/appScreenshots", limit=50)['data']:
                            api.delete(f"/v1/appScreenshots/{old['id']}")
                    else:
                        s = api.post('/v1/appScreenshotSets', {'data': {'type': 'appScreenshotSets', 'attributes': {
                            'screenshotDisplayType': display}, 'relationships': {
                            'appStoreVersionLocalization': rel('appStoreVersionLocalizations', loc['id'])}}})['data']
                    for f in files:
                        uploaded.append((f'{cfg["locales"][lang]} {f.parent.parent.name}/{f.name}',
                                         upload_shot(api, s['id'], f)))
                    print(f"   {cfg['locales'][lang]} {folder}: {len(files)} uploaded ({display})")
                    done = True
                    break
                except ApiError as e:
                    print(f"   {cfg['locales'][lang]} {folder} as {display}: {e}")
            if not done:
                failures.append(f"screenshots {cfg['locales'][lang]} {folder}: no display type accepted")
    # Apple checks each image after the upload (its size above all); wait for the verdicts.
    pending = dict(uploaded)
    for _ in range(40):
        for name, sid in list(pending.items()):
            st = api.get(f'/v1/appScreenshots/{sid}')['data']['attributes'].get('assetDeliveryState') or {}
            if st.get('state') == 'COMPLETE':
                del pending[name]
            elif st.get('state') == 'FAILED':
                errs = '; '.join(e.get('description') or e.get('code', '') for e in st.get('errors') or [])
                print(f'   {name} REJECTED: {errs}')
                failures.append(f'screenshot {name}: {errs}')
                del pending[name]
        if not pending:
            break
        time.sleep(6)
    print(f'   {len(uploaded) - len(pending)} of {len(uploaded)} checked by Apple'
          + (f', {len(pending)} still processing' if pending else ''))


@step('App Review information')
def review(api, ver, cfg):
    attrs = {'notes': cfg['reviewNotes'], 'demoAccountRequired': False}
    # The App Review contact, from the run's inputs (masked in the logs; never stored in this public repo).
    for k, env in (('contactFirstName', 'REVIEW_FIRST_NAME'), ('contactLastName', 'REVIEW_LAST_NAME'),
                   ('contactEmail', 'REVIEW_EMAIL'), ('contactPhone', 'REVIEW_PHONE')):
        if os.environ.get(env):
            attrs[k] = os.environ[env].strip()
    try:
        d = api.get(f"/v1/appStoreVersions/{ver['id']}/appStoreReviewDetail")['data']
    except ApiError:
        d = None
    if d:
        api.patch(f"/v1/appStoreReviewDetails/{d['id']}",
                  {'data': {'type': 'appStoreReviewDetails', 'id': d['id'], 'attributes': attrs}})
    else:
        api.post('/v1/appStoreReviewDetails', {'data': {'type': 'appStoreReviewDetails', 'attributes': attrs,
                                                         'relationships': {'appStoreVersion': rel('appStoreVersions', ver['id'])}}})
    print('   notes and contact set')


@step('Submit for review')
def submit(api, app, ver):
    sub = api.post('/v1/reviewSubmissions', {'data': {'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'},
                                                       'relationships': {'app': rel('apps', app['id'])}}})['data']
    api.post('/v1/reviewSubmissionItems', {'data': {'type': 'reviewSubmissionItems', 'relationships': {
        'reviewSubmission': rel('reviewSubmissions', sub['id']),
        'appStoreVersion': rel('appStoreVersions', ver['id'])}}})
    api.patch(f"/v1/reviewSubmissions/{sub['id']}", {'data': {'type': 'reviewSubmissions', 'id': sub['id'],
                                                               'attributes': {'submitted': True}}})
    print('   submitted to App Review')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--submit', action='store_true', help='also submit the version for review')
    ap.add_argument('--copyright', default='')
    args = ap.parse_args()
    listing = json.loads((HERE / 'appstore-metadata' / 'listing.json').read_text())
    cfg, meta = listing['common'], listing['locales']
    if args.copyright:
        cfg['copyright'] = args.copyright
    api = Api()
    app = find_app(api, cfg['bundleId'])
    if not app:
        sys.exit(1)
    info = app_info(api, app, cfg, meta)
    if info:
        age_rating(api, info)
    price(api, app)
    ver = version(api, app, cfg)
    if not ver:
        sys.exit(1)
    first = len(api.get(f"/v1/apps/{app['id']}/appStoreVersions", **{'filter[platform]': 'IOS'})['data']) <= 1
    locs = version_texts(api, ver, cfg, meta, first) or {}
    attach_build(api, app, ver, cfg)
    screenshots(api, locs, cfg)
    review(api, ver, cfg)
    if args.submit:
        if failures:
            print('\nNot submitting: fix the failures above first.')
        else:
            submit(api, app, ver)
    print('\n' + ('All done.' if not failures else 'Failures:\n  ' + '\n  '.join(failures)))
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
