export default function LiveQueue({ riders = [] }) {
  return <section aria-label="Live queue"><h2>Live queue</h2><p>{riders.length} riders waiting</p></section>;
}