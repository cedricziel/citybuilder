import type { CSSProperties } from "react";
import { Button } from "../Button/Button";
import "./TitleScreen.css";

export interface TitleScreenProps {
  /** The latest save's name, e.g. "Greenhold — Spring 1206". Omit when there is no save: Continue disappears. */
  continueSave?: string;
  /** Show Quit (macOS only). Default false. */
  showQuit?: boolean;
  style?: CSSProperties;
  onContinue?: () => void;
  onNewGame?: () => void;
  onSettings?: () => void;
  onQuit?: () => void;
}

/** The launch screen: serif "Citybuilder" wordmark over a column of 280px buttons. Fills its parent. */
export function TitleScreen({ continueSave, showQuit, style, onContinue, onNewGame, onSettings, onQuit }: TitleScreenProps) {
  return (
    <div className="cb-title-screen" style={style}>
      <h1 className="cb-title-screen__wordmark">Citybuilder</h1>
      <div className="cb-title-screen__buttons">
        {continueSave ? (
          <button type="button" className="cb-title-screen__continue" onClick={onContinue}>
            <span className="cb-title-screen__continue-title">Continue</span>
            <span className="cb-title-screen__continue-save">{continueSave}</span>
          </button>
        ) : null}
        <Button variant="bordered" fullWidth onClick={onNewGame}>
          New Game…
        </Button>
        <Button variant="bordered" fullWidth onClick={onSettings}>
          Settings
        </Button>
        {showQuit ? (
          <Button variant="bordered" fullWidth onClick={onQuit}>
            Quit
          </Button>
        ) : null}
      </div>
    </div>
  );
}
