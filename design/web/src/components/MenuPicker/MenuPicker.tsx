import { Icon } from "../Icon/Icon";
import "./MenuPicker.css";

export interface MenuPickerProps {
  /** Leading label ("Export", "Starting age"). Omit when a heading above names it. */
  label?: string;
  options: string[];
  selected: string;
  /** `small` for caption-sized pickers (inspector), `regular` for dialogs. */
  size?: "small" | "regular";
  onChange?: (option: string) => void;
}

/**
 * A `Picker` with `.pickerStyle(.menu)`: the selected value in accent with
 * an up-down chevron. Backed by a native `<select>` so it works in designs.
 */
export function MenuPicker({ label, options, selected, size = "regular", onChange }: MenuPickerProps) {
  return (
    <label className={`cb-menu-picker cb-menu-picker--${size}`}>
      {label ? <span className="cb-menu-picker__label">{label}</span> : null}
      <span className="cb-menu-picker__value">
        <select value={selected} onChange={(event) => onChange?.(event.target.value)} aria-label={label}>
          {options.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
        <span className="cb-menu-picker__shown">{selected}</span>
        <Icon name="chevron.down" size={size === "small" ? 10 : 13} />
      </span>
    </label>
  );
}
