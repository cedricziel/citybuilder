## ADDED Requirements

### Requirement: Order board

A game with an active calendar SHALL offer an order board from the HUD, on iPhone, iPad, Mac and Apple TV. The board SHALL list the open orders, accepted first and then offers by deadline, as cards. A card's status line SHALL read "Offer ends with <season>" for an offer, "In stores X of Q" for an accepted crown order with nothing sent (with ", too late to send" when a shipment could no longer arrive in time, and "No town center to send to" without a town center), "Delivered X of Q, Y on the road" once goods are sent, and "Delivered X of Q by ship" for a rival's. Each card SHALL show the issuer, the title, the good and quantity, the deadline as a date, the reward and the favour at stake. An offer SHALL show Accept and Decline. An accepted crown order SHALL show how much of the good the stores hold against the quantity and a Send button, enabled only when the plan exists; an accepted rival order SHALL show the units delivered. An accepted order that has nothing sent SHALL show Abandon. Accept SHALL be disabled with 2 orders accepted. The board SHALL show the favour of the crown and of each rival with its step and its perk, and every control SHALL be disabled after the game is over. The look comes from the approved canvas.

#### Scenario: Board lists accepted orders first

- **WHEN** the board holds one accepted order and two offers
- **THEN** the accepted order is the first card, and the offers follow by deadline

#### Scenario: Offers appear in deadline order

- **WHEN** the board holds three offers with deadlines in Autumn, Spring and Summer
- **THEN** the cards list the Spring offer, then the Summer offer, then the Autumn offer

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
- **THEN** Send is disabled and the card reads "In stores 29 of 30", and then Send is enabled, the card reads "In stores 30 of 30" and Send enqueues `dispatchOrder`

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

The HUD SHALL show an orders entry with the count of accepted orders over the open limit and a mark when an offer waits. On iPad, Mac and Apple TV it SHALL be a capsule ("Orders 1/2") at the left of the menu buttons; on an iPhone it SHALL be a round button with the count as its badge, and in the More menu of a phone in portrait it SHALL be an item. Activating it SHALL open or close the board. The entry SHALL be hidden in games without an active calendar.

#### Scenario: Chip counts accepted orders

- **WHEN** one order is accepted and an offer waits
- **THEN** the chip reads "Orders 1/2", its badge reads 1 and it shows the offer mark

#### Scenario: Chip is hidden without a calendar

- **WHEN** the world's calendar is inactive
- **THEN** the HUD shows no orders entry

#### Scenario: Chip opens the board

- **WHEN** the player taps the chip
- **THEN** the board opens

### Requirement: Order board layout

The order board SHALL be a column on the trailing edge, `OrderBoardLayout.width` points wide (340 on iPad and Mac, 300 on a phone in landscape, 520 on Apple TV), and SHALL sit between the menu buttons and the free space below them. Its frame SHALL be computed from the same inputs as the minimap card, the first-steps card and the build controls, and SHALL never overlap any of them:

- with the build rail (the minimap at the bottom right), it SHALL end 8 points above the minimap card, or above the tool strip row when the minimap is hidden;
- with the dock (the minimap at the top right under the menu buttons), it SHALL begin 8 points below the minimap card and end above the dock and the tool strip;
- it SHALL never reach the build rail or the dock, which are on the leading edge and the bottom;
- the card list SHALL scroll inside whatever height is left, and the board SHALL be at least 160 points tall or not shown as a column (see compact widths below). Wherever the column cannot be given its 160 points, the board SHALL show as a sheet, and the inspector SHALL NOT make room for a board that is not shown as a column.

The first-steps card SHALL collapse to its capsule while the board is open. The inspector callout SHALL place itself in the area outside the board's frame, flipping to the other side of its building as it does for the minimap, so the inspector and the board stay open together in regular widths.

In a compact width (the phone, or a window where the callout, the board and the rail cannot fit together) one SHALL replace the other: opening the board SHALL close the inspector callout and clear the selection, and selecting a building SHALL close the board. On a phone in portrait the board SHALL be a sheet. On Apple TV the board SHALL be a focus column that takes focus when it opens and returns it to the map when it closes.

#### Scenario: Board stays clear of the minimap and the build rail

- **WHEN** the board frame is computed for every size class (phone landscape, iPad landscape and portrait, Mac window, Apple TV), with the minimap shown and hidden, in both the rail and dock layouts
- **THEN** it overlaps neither the minimap card, nor the build rail or dock, nor the tool strip row, nor the menu buttons, and lies inside the safe area

#### Scenario: Minimap at the top right pushes the board down

- **WHEN** the layout is the dock and the minimap is shown
- **THEN** the board starts 8 points below the minimap card

#### Scenario: Opening the board collapses the first-steps card

- **WHEN** the first-steps card is expanded and the board opens
- **THEN** the card shows as its capsule until the board closes

#### Scenario: Inspector and board coexist in regular widths

- **WHEN** the board is open on an iPad in landscape and the player selects a building
- **THEN** the inspector callout appears outside the board's frame, on the other side of the building if needed, and the board stays open

#### Scenario: One replaces the other in a compact width

- **WHEN** the board is open on a phone in landscape and the player selects a building, and then opens the board with a building selected
- **THEN** the first selection closes the board, and the second closes the callout and clears the selection

#### Scenario: Board is a sheet on a phone in portrait

- **WHEN** the board is opened on a phone in portrait
- **THEN** it shows as a sheet over the game and has no column frame
