"""Invites someone to the App Store Connect team (Developer role, all apps visible), so they can be an internal
TestFlight tester. The address comes from INVITE_EMAIL and is never printed (the run logs are public).
Run by .github/workflows/team-invite.yml."""
import os
import sys

from appstore_listing import Api, ApiError


def main():
    email = os.environ['INVITE_EMAIL'].strip()
    first, _, last = os.environ.get('INVITE_NAME', '').strip().partition(' ')
    api = Api()
    try:
        api.post('/v1/userInvitations', {'data': {'type': 'userInvitations', 'attributes': {
            'email': email, 'firstName': first or 'Tester', 'lastName': last or 'Mushaf',
            'roles': ['DEVELOPER'], 'allAppsVisible': True, 'provisioningAllowed': False}}})
        print('Invitation sent: accept it from the email, then run "TestFlight internal testers".')
    except ApiError as e:
        print(f"FAILED: {str(e).replace(email, '<email>')}")
        sys.exit(1)


if __name__ == '__main__':
    main()
