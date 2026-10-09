import { NewGameDialog } from "@citybuilder/ui";

export const Sandbox = () => <NewGameDialog width={440} />;

export const Scenario = () => <NewGameDialog width={440} mode="Scenario" scenario="The Guild Town" seedMode="Random" />;

export const CustomSeed = () => <NewGameDialog width={440} seedMode="Custom" seed="12x" startDisabled culture="East Asian" age="Antiquity" />;
