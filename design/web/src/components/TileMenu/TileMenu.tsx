import "./TileMenu.css";

export interface TileMenuItem {
  /** "House — $120", "Brewery — Needs research", "Demolish". */
  title: string;
  disabled?: boolean;
  destructive?: boolean;
}

export interface TileMenuProps {
  /** Build rows in palette order, then Demolish when the tile is occupied. */
  items: TileMenuItem[];
  /** Cancel title. Default "Cancel". */
  cancelLabel?: string;
  width?: number;
  onSelect?: (title: string) => void;
  onCancel?: () => void;
}

/**
 * The iOS long-press tile menu: a `confirmationDialog` action sheet with a
 * row per building (name and cost, or why it is disabled), Demolish, and a
 * separate bold Cancel.
 */
export function TileMenu({ items, cancelLabel = "Cancel", width = 360, onSelect, onCancel }: TileMenuProps) {
  return (
    <div className="cb-action-sheet" style={{ width }}>
      <div className="cb-action-sheet__group">
        {items.map((item) => (
          <button
            key={item.title}
            type="button"
            className={`cb-action-sheet__row ${item.destructive ? "cb-action-sheet__row--destructive" : ""}`}
            disabled={item.disabled}
            onClick={() => onSelect?.(item.title)}
          >
            {item.title}
          </button>
        ))}
      </div>
      <button type="button" className="cb-action-sheet__row cb-action-sheet__cancel" onClick={onCancel}>
        {cancelLabel}
      </button>
    </div>
  );
}
