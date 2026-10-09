import "./RejectionBanner.css";

export interface RejectionBannerProps {
  /** Why the placement failed, e.g. "Needs a road" or "Not enough money". */
  message: string;
}

/** The red capsule naming why the last placement was rejected. Shown for 2.5 s in the app. */
export function RejectionBanner({ message }: RejectionBannerProps) {
  return (
    <div className="cb-rejection" role="status" aria-label={`Can't place: ${message}`}>
      {message}
    </div>
  );
}
