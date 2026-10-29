/// The community rules students accept during onboarding. The version the
/// backend expects comes from `GET /me` (`current_terms_version`).
const termsSections = <(String, String)>[
  (
    'Be honest about your items',
    'Describe items accurately, with real photos and any defects. Only list '
        'things you own and are allowed to rent out or sell.',
  ),
  (
    'Hand over with the code',
    'Pickups and returns are confirmed with a one-time code shown in the app. '
        'Never share your code before the item is in front of you.',
  ),
  (
    'Pay through UniRent',
    'Pay rent, extensions and charges in the app (UPI) or as recorded in the '
        'app. Don’t arrange side payments.',
  ),
  (
    'Return on time',
    'Return items by the agreed time. Late returns are charged the late fee '
        'shown on the booking, and repeated lateness lowers your trust score.',
  ),
  (
    'Look after what you borrow',
    'You are responsible for damage beyond normal wear while an item is with '
        'you. Owners can record damage charges, which you can appeal.',
  ),
  (
    'Respect each other',
    'Be polite and reliable. Harassment, discrimination or threats lead to '
        'suspension.',
  ),
  (
    'No prohibited items',
    'Don’t list anything illegal, unsafe, or against college rules.',
  ),
  (
    'Reviews and trust',
    'After each trade both sides review each other. Reviews and completed '
        'trades build the trust score others see on your profile.',
  ),
  (
    'Disputes',
    'If something goes wrong, file an appeal from the booking. Moderators '
        'review the evidence and their ruling applies to both sides.',
  ),
  (
    'Your data',
    'Your phone number and residence are shared only with people you have an '
        'approved booking with. Staff can see your details to resolve issues.',
  ),
];
