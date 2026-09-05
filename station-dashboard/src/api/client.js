export async function getLiveQueue() {
    const response = await fetch('/api/station/queue');
    if (!response.ok) throw new Error('Unable to load the live queue');
    return response.json();
}