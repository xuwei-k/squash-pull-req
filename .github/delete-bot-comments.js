module.exports = ({github, context}) => {
  (async () => {
    //console.log(context);
    const comments = await github.issues.listComments({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: context.payload.pull_request.number
    });
    //console.log(comments);
    //console.log(comments.data);

    const bot_comments = comments.data.filter(c => c.user.login === 'github-actions[bot]');
    console.log(bot_comments);
    for (const c of bot_comments) {
      console.log(c);
      console.log(c.id);
      await github.issues.deleteComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        comment_id: c.id
      });
    }
  })();
};
