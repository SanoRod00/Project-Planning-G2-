export async function handler(event) {
    return { batchItemFailures: [], received: event?.Records?.length || 0 };
}