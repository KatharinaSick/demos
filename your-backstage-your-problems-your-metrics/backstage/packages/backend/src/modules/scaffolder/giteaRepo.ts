import { createBackendModule, coreServices } from '@backstage/backend-plugin-api';
import { scaffolderActionsExtensionPoint } from '@backstage/plugin-scaffolder-node/alpha';
import { createGiteaRepoAction } from './createGiteaRepoAction';

export const scaffolderModuleGiteaRepo = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'gitea-repo',
  register(reg) {
    reg.registerInit({
      deps: {
        actions: scaffolderActionsExtensionPoint,
        config: coreServices.rootConfig,
      },
      async init({ actions, config }) {
        actions.addActions(createGiteaRepoAction({ config }));
      },
    });
  },
});
