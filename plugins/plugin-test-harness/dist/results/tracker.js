export class ResultsTracker {
    results = new Map(); // testId -> history
    record(result) {
        const history = this.results.get(result.testId) ?? [];
        history.push(result);
        this.results.set(result.testId, history);
    }
    getHistory(testId) {
        return this.results.get(testId) ?? [];
    }
    getLatest(testId) {
        const history = this.getHistory(testId);
        return history[history.length - 1];
    }
    getPassCount() {
        let count = 0;
        for (const [testId] of this.results) {
            const latest = this.getLatest(testId);
            if (latest?.status === 'passing')
                count++;
        }
        return count;
    }
    getFailCount() {
        let count = 0;
        for (const [testId] of this.results) {
            const latest = this.getLatest(testId);
            if (latest?.status === 'failing')
                count++;
        }
        return count;
    }
    getFailingTests() {
        const failing = [];
        for (const [testId] of this.results) {
            const latest = this.getLatest(testId);
            if (latest?.status === 'failing')
                failing.push(latest);
        }
        return failing;
    }
    getAllLatest() {
        return Array.from(this.results.keys())
            .map(id => this.getLatest(id))
            .filter((r) => r !== undefined);
    }
}
//# sourceMappingURL=tracker.js.map