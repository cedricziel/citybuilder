import "./SegmentedPicker.css";

export interface SegmentedPickerProps {
  /** Segment titles, e.g. ["Sandbox", "Scenario"]. */
  options: string[];
  selected: string;
  onChange?: (option: string) => void;
  /** Accessible name for the group. */
  label?: string;
}

/** A `Picker` with `.pickerStyle(.segmented)`: the iOS sliding segmented control, full width. */
export function SegmentedPicker({ options, selected, onChange, label }: SegmentedPickerProps) {
  return (
    <div className="cb-segmented" role="radiogroup" aria-label={label}>
      {options.map((option) => (
        <button
          key={option}
          type="button"
          role="radio"
          aria-checked={option === selected}
          className={`cb-segmented__item ${option === selected ? "cb-segmented__item--on" : ""}`}
          onClick={() => onChange?.(option)}
        >
          {option}
        </button>
      ))}
    </div>
  );
}
