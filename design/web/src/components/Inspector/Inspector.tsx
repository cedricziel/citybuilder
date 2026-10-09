import { Glass } from "../Glass/Glass";
import { Button } from "../Button/Button";
import { MenuPicker } from "../MenuPicker/MenuPicker";
import "./Inspector.css";

export interface InspectorProps {
  /**
   * The model's lines, one per row in caption monospaced: "Kind: house",
   * "State: operational", "Residents: 6/8", "Needs: food ✓ · planks ✗" ...
   * Empty -> renders nothing.
   */
  lines: string[];
  /** The gallery's commission button: its title and whether the city can afford it. */
  commission?: { title: string; enabled: boolean };
  /** The caravanserai's export picker: the options and the selected one. */
  exportPicker?: { options: string[]; selected: string };
  onCommission?: () => void;
  onPickExport?: (option: string) => void;
}

/** The bottom-left panel describing the selected building, on a 10px glass card. */
export function Inspector({ lines, commission, exportPicker, onCommission, onPickExport }: InspectorProps) {
  if (lines.length === 0) return null;
  return (
    <Glass radius={10} padding={12} className="cb-inspector">
      {lines.map((line) => (
        <div key={line} className="cb-inspector__line">
          {line}
        </div>
      ))}
      {commission ? (
        <Button variant="borderless" size="small" disabled={!commission.enabled} onClick={onCommission} style={{ alignSelf: "flex-start" }}>
          {commission.title}
        </Button>
      ) : null}
      {exportPicker ? (
        <MenuPicker label="Export" size="small" options={exportPicker.options} selected={exportPicker.selected} onChange={onPickExport} />
      ) : null}
    </Glass>
  );
}
