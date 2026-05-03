dimport { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { Config } from '@backstage/config';

export function createGiteaFileAction({ config }: { config: Config }) {
  return createTemplateAction({
    id: 'gitea:file:create',
    description: 'Creates or updates a file in an existing Gitea repository.',
    schema: {
      input: z =>
        z.object({
          repoName: z.string().describe('Name of the existing repository'),
          filePath: z.string().describe('Path of the file to create within the repository'),
          content: z.string().describe('Content of the file'),
          commitMessage: z.string().optional().describe('Commit message'),
          branch: z.string().optional().describe('Branch to commit to'),
        }),
    },
    async handler(ctx) {
      const {
        repoName,
        filePath,
        content,
        commitMessage = `chore: add ${filePath}`,
        branch = 'main',
      } = ctx.input;

      const baseUrl = config.getString('gitea.baseUrl');
      const username = config.getString('gitea.username');
      const password = config.getString('gitea.password');
      const auth = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;

      const apiUrl = `${baseUrl}/api/v1/repos/${username}/${repoName}/contents/${filePath}`;

      // Check if the file already exists so we can include its SHA for updates.
      let sha: string | undefined;
      const existing = await fetch(`${apiUrl}?ref=${branch}`, {
        headers: { Authorization: auth },
      });
      if (existing.ok) {
        const data = (await existing.json()) as { sha: string };
        sha = data.sha;
      }

      ctx.logger.info(`Writing ${filePath} to ${repoName}`);

      const response = await fetch(apiUrl, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: auth },
        body: JSON.stringify({
          message: commitMessage,
          content: Buffer.from(content).toString('base64'),
          branch,
          ...(sha ? { sha } : {}),
        }),
      });

      if (!response.ok) {
        throw new Error(
          `Failed to write file to Gitea: ${response.status} ${await response.text()}`,
        );
      }
    },
  });
}
