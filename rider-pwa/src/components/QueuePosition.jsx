export default function QueuePosition({ position, estimatedWait }) {
    return <section aria-label="Queue position">Position: {position} · Estimated wait: {estimatedWait}</section>;
}