# CloudKit schema

Container: `iCloud.com.cedricziel.citybuilder`. Database: private. Zone: the default private zone.

## Record type `CitySave`

The client keeps one record for each game. The record name is the game ID as an uppercase UUID string, so a second upload for a game replaces the first record.

| Field           | Type   | Notes                                                     |
| --------------- | ------ | --------------------------------------------------------- |
| `gameID`        | String | The game ID as a UUID string. It matches the record name. |
| `body`          | Asset  | The encoded save file.                                    |
| `currentDevice` | String | The device that uploaded the record last.                 |

The client reads the modification date from the record's system field. The record type has no field of its own for it.

## Indexes

| Field        | Index     | Why                                                                                                                   |
| ------------ | --------- | --------------------------------------------------------------------------------------------------------------------- |
| `recordName` | Queryable | `listGames()` queries every `CitySave` record. CloudKit refuses a query on a record type that has no queryable index. |

## Deploying

1. In development, the first upload creates the record type. You can also create it by hand in the CloudKit console.
2. In the console, add the `recordName` queryable index to `CitySave`.
3. Deploy the schema to production. TestFlight and App Store builds use the production environment and cannot sync until this step is done.
