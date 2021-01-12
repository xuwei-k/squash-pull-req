module.exports = ({github, context}) => {
  (async () => {
    const pulls = await github.pulls.list({
      owner: context.repo.owner,
      repo: context.repo.repo,
      per_page: 100
    });
    for (const pull of pulls.data) {
      const pullReq = await github.pulls.get({
        owner: context.repo.owner,
        repo: context.repo.repo,
        pull_number: pull.number
      });
      if (pullReq.data.mergeable === false) {
        const comments = await github.pulls.listReviewComments({
          owner: context.repo.owner,
          repo: context.repo.repo,
          per_page: 100,
          pull_number: pull.number
        });
        const conflictComment = "コンフリクトしています";
        if (undefined === comments.data.filter(c => c.user.login === "bot").find(c => c.body === conflictComment)){
          await github.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: pull.number,
            body: conflictComment
          });
        }
      }
    }
  })();
};
