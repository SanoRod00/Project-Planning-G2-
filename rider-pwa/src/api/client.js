export async function reserveQueueSpot() {
    const response = await fetch('/api/queue/reserve', { method: 'POST' });
    if (!response.ok) throw new Error('Unable to reserve a queue spot');
    return response.json();
}