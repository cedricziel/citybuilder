## ADDED Requirements

### Requirement: Order board

A game with an active calendar SHALL offer an order board from the HUD, on iPhone, iPad, Mac and Apple TV. The board SHALL list the open orders, accepted first and then offers by deadline, as cards. Each card SHALL show the issuer, the title, the good and quantity, the deadline as a date, the reward and the favour at stake. An offer SHALL show Accept and Decline. An accepted crown order SHALL show how much of the good the stores hold against the quantity and a Send button, enabled only when the plan exists; an accepted rival order SHALL show the units delivered. An accepted order that has nothing sent SHALL show Abandon. Accept SHALL be disabled with 2 orders accepted. The board SHALL show the favour of the crown and of each rival with its step and its perk, and every control SHALL be disabled after the game is over. The look comes from the approved canvas.

#### Scenario: Board lists accepted orders first

- **WHEN** the board holds one accepted order and two offers
- **THEN** the accepted order is the first card, and the offers follow by deadline

#### Scenario: A card shows what the order needs

- **WHEN** a crown offer for 54 planks with a $540 reward and a deadline in Spring 1203 is shown
- **THEN** its card shows the crown, the title, 54 planks, "by Spring 1203", $540 and +2 favour

#### Scenario: Accept and decline enqueue commands

- **WHEN** the player taps Accept on an offer, and Decline on another
- **THEN** `acceptOrder` and `declineOrder` are enqueued for those orders

#### Scenario: Accept is disabled at the open limit

- **WHEN** two orders are accepted
- **THEN** every offer's Accept button is disabled

#### Scenario: Send is enabled when the stores hold enough

- **WHEN** an accepted crown order for 30 planks shows while the stores hold 29, and then 30
- **THEN** Send is disabled and reads "29 of 30 in stores", and then Send is enabled and enqueues `dispatchOrder`

#### Scenario: Favour readout lists perks

- **WHEN** the crown's favour is 6
- **THEN** the readout shows favour 6, the first step and "Research costs 3% less"

#### Scenario: The board locks after game over

- **WHEN** the game is over
- **THEN** every board button is disabled

### Requirement: Order notifications

The game screen SHALL raise a banner when an order is offered, fulfilled or missed, and a lighter notice when one lapses. The banner for an offer SHALL name the issuer and the good and SHALL open the board. The banner for a fulfilled order SHALL name the reward. The banner for a missed order SHALL name the favour lost. Order banners SHALL queue behind the game-over and deficit banners.

#### Scenario: An offer raises a banner

- **WHEN** a tick emits `orderOffered`
- **THEN** the session shows a banner naming the issuer and the good

#### Scenario: A fulfilled order raises a banner

- **WHEN** a tick emits `orderFulfilled` with a reward of $540
- **THEN** the session shows a banner naming $540

#### Scenario: A missed order raises a banner

- **WHEN** a tick emits `orderFailed`
- **THEN** the session shows a banner naming the favour lost

### Requirement: Orders chip in the HUD

The HUD SHALL show a chip with the count of accepted orders over the open limit and a mark when an offer waits. Tapping it SHALL open the board. The chip SHALL be hidden in games without an active calendar.

#### Scenario: Chip counts accepted orders

- **WHEN** one order is accepted and an offer waits
- **THEN** the chip reads 1/2 and shows the offer mark

#### Scenario: Chip opens the board

- **WHEN** the player taps the chip
- **THEN** the board opens
