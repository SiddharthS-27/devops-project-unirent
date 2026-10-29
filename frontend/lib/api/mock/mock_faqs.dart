/// The help bot's FAQs (backend migration 0013_faqs). `{late_fee_rule}`
/// is filled in from the current rule.
const mockFaqs = <(String topic, String question, String answer, List<String> keywords)>[
  (
    'booking',
    'How do I rent an item?',
    'Search on Home, open the listing and tap Request to rent. Pick the start and end time; you\'ll see the total rent, the late-fee rule and the grace period before you send. The owner has 24 hours to approve or decline.',
    ['rent', 'request', 'book', 'booking', 'borrow', 'steps'],
  ),
  (
    'booking',
    'How does pickup work?',
    'Meet at the pickup point. Both of you upload photos of the item, you pay by UPI in the app or in cash, then you show your code and the owner types it. The rental is then active.',
    ['pickup', 'collect', 'handover', 'otp', 'code', 'meet'],
  ),
  (
    'booking',
    'How do I return an item?',
    'Meet the owner and tap Start return. Upload your photos, the owner inspects the item and uploads theirs, then the owner shows a code and you type it. Pay any late fee or agreed damage charge, and the owner taps Proceed.',
    ['return', 'give', 'back', 'proceed', 'inspection'],
  ),
  (
    'fees',
    'What is the late fee?',
    '{late_fee_rule} Both of you get alerts every hour while an item is overdue.',
    ['late', 'fee', 'overdue', 'grace', 'penalty', 'fine'],
  ),
  (
    'booking',
    'Can I cancel a booking?',
    'Either side can cancel after approval, until the pickup payment and code. You must add a note saying why; the other side reads it and rates you, and cancellations show on your profile. There is no fee.',
    ['cancel', 'cancellation', 'cancelled', 'note'],
  ),
  (
    'booking',
    'What if the owner doesn\'t answer my request?',
    'You can withdraw a pending request any time. If the owner doesn\'t answer within 24 hours it expires. Neither counts as a cancellation.',
    ['withdraw', 'expire', 'expired', 'pending', 'answer', 'respond'],
  ),
  (
    'payments',
    'How do payments work?',
    'Pay by UPI through Razorpay in the app, or in cash that the owner marks as received. UPI money goes straight to the owner\'s bank account. Tapping Pay twice never charges twice.',
    ['pay', 'payment', 'upi', 'cash', 'razorpay', 'charged'],
  ),
  (
    'payments',
    'Is there a deposit or a platform fee?',
    'No. UniRent takes no fee and asks for no deposit. You pay the rent, plus any late fee or damage charge agreed at return.',
    ['deposit', 'platform', 'commission', 'fee', 'free'],
  ),
  (
    'payments',
    'How do refunds work?',
    'Refunds happen only after a moderator or admin ruling on an appeal. UPI refunds go back through Razorpay; cash refunds are handed back and marked by the owner.',
    ['refund', 'refunds', 'money', 'back'],
  ),
  (
    'trust',
    'How do reviews work?',
    'After every trade both sides review each other: stars for a few parameters and a comment. Reviews stay hidden until both of you submit, or 24 hours after the first, so neither can retaliate. Reviewing is compulsory.',
    ['review', 'reviews', 'rating', 'rate', 'stars', 'feedback'],
  ),
  (
    'trust',
    'What is the trust score and the New badge?',
    'Each student has a lender and a renter trust score from 0 to 100, built from ratings, on-time returns, damage, cancellations and account age. It shows after 5 completed trades; until then you have the New badge. Trust only affects search ranking.',
    ['trust', 'score', 'badge', 'new', 'ranking'],
  ),
  (
    'disputes',
    'How do I appeal a damage charge?',
    'If you can\'t agree on a charge at return, either of you can file an appeal from the booking. The handover photos attach automatically and you can add notes and photos. A moderator rules, and the admin can overrule.',
    ['appeal', 'dispute', 'damage', 'disagree', 'unfair', 'charge'],
  ),
  (
    'disputes',
    'What if my item isn\'t returned?',
    'Once a rental is an hour overdue you can escalate it from the booking, and moderators follow up in person. Before that you can reach a moderator from this chat any time.',
    ['returned', 'missing', 'stolen', 'escalate', 'overdue', 'late'],
  ),
  (
    'listing',
    'How do I list an item?',
    'Link your Razorpay payout account from Profile first, then open Listings and tap Add. Add photos, the price per hour or day (or a sale price) and the pickup point.',
    ['list', 'listing', 'sell', 'lend', 'post', 'payout', 'add'],
  ),
  (
    'booking',
    'Can I extend my rental?',
    'Yes. Request more time from the active rental; the owner approves or declines. Extra time costs the listing\'s rate, paid by UPI when approved or in cash at return.',
    ['extend', 'extension', 'more', 'time', 'longer'],
  ),
  (
    'privacy',
    'Who can see my hostel and room?',
    'Only moderators, the admin, and the other side of a booking once it is approved. Your phone number is public so people can call you to negotiate.',
    ['hostel', 'room', 'address', 'privacy', 'see', 'phone', 'residence'],
  ),
];
