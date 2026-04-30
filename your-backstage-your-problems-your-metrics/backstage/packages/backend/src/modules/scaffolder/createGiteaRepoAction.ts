import path from 'path';
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { Config } from '@backstage/config';
import { context, propagation } from '@opentelemetry/api';
import { simpleGit } from 'simple-git';

export function createGiteaRepoAction({ config }: { config: Config }) {
  return createTemplateAction({
    id: 'gitea:repo:create',
    description:
      'Creates a Gitea repository and pushes the workspace with the OTel traceparent in the initial commit message.',
    schema: {
      input: z =>
        z.object({
          repoName: z.string().describe('Name of the repository to create'),
          description: z.string().optional().describe('Repository description'),
          defaultBranch: z.string().optional().describe('Default branch name'),
          sourcePath: z
            .string()
            .optional()
            .describe('Relative path within the workspace to use as repository root'),
        }),
      output: z =>
        z.object({
          repoUrl: z.string(),
          cloneUrl: z.string(),
        }),
    },
    async handler(ctx) {
      const { repoName, description, defaultBranch = 'main', sourcePath = '.' } = ctx.input;

      const baseUrl = config.getString('gitea.baseUrl');
      const username = config.getString('gitea.username');
      const password = config.getString('gitea.password');

      ctx.logger.info(`Creating Gitea repo: ${repoName}`);

      const response = await fetch(`${baseUrl}/api/v1/user/repos`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`,
        },
        body: JSON.stringify({
          name: repoName,
          description: description ?? '',
          private: false,
          default_branch: defaultBranch,
          auto_init: false,
        }),
      });

      if (!response.ok) {
        throw new Error(
          `Failed to create Gitea repo: ${response.status} ${await response.text()}`,
        );
      }

      const repo = (await response.json()) as {
        clone_url: string;
        html_url: string;
      };

      // Inject the active OTel span context to get the traceparent, so the
      // Argo Workflow triggered by this repo's first push can continue the trace.
      const carrier: Record<string, string> = {};
      propagation.inject(context.active(), carrier);
      const traceparent = carrier['traceparent'];

      const commitMessage = traceparent
        ? `feat: initialize service from Backstage template\n\nTrace-Parent: ${traceparent}`
        : 'feat: initialize service from Backstage template';

      ctx.logger.info(`Pushing workspace to ${repo.html_url}`);

      const authenticatedCloneUrl = repo.clone_url.replace(
        '://',
        `://${username}:${password}@`,
      );

      const repoPath = path.join(ctx.workspacePath, sourcePath);
      const git = simpleGit(repoPath);
      await git.init();
      await git.addConfig('user.name', 'Backstage Scaffolder');
      await git.addConfig('user.email', 'scaffolder@backstage.io');
      await git.add('.');
      await git.commit(commitMessage);
      await git.addRemote('origin', authenticatedCloneUrl);
      await git.push('origin', defaultBranch, ['--set-upstream']);

      ctx.output('repoUrl', repo.html_url);
      ctx.output('cloneUrl', repo.clone_url);
    },
  });
}
