module.exports = ({github, context}) => {
  (async () => {
    console.log(github);
    console.log(context);
    const pull_req = await github.pulls.get({
      owner: context.repo.owner,
      repo: context.repo.repo,
      pull_number: github.issue.number
    });
    console.log(pull_req);
    console.log(pull_req.head);
    console.log(pull_req.head.ref);
    if (pull_req.head.ref === "ppp") {
      throw "このbranchはrebase禁止";
    }
  })();
};
