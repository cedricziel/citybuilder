import { PauseMenu, defaultPauseActions } from "@citybuilder/ui";

export const iOS = () => <PauseMenu width={390} />;

export const Saved = () => <PauseMenu width={390} status="Game saved." />;

export const Mac = () => (
  <PauseMenu width={390} actions={[...defaultPauseActions, { label: "Quit", icon: "power", destructive: true }]} />
);
