import { createBackendModule, coreServices } from '@backstage/backend-plugin-api';
import { scaffolderActionsExtensionPoint } from '@backstage/plugin-scaffolder-node';
import { createGiteaRepoAction } from './createGiteaRepoAction';

const scaffolderModuleGiteaRepo = createBackendModule({
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

export default scaffolderModuleGiteaRepo;
