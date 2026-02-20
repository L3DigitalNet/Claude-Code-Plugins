// Factory for distro-specific command adapters.
// Called in server.ts Phase 4 after detectDistro(); the returned DistroCommands is
// passed into PluginContext and used by all tool modules for package/service commands.
// Adding a new distro family requires: (1) a new Commands class, (2) a new case here,
// and (3) updating detectDistro() to emit the new family string.

import type { DistroContext } from "../../types/distro.js";
import type { DistroCommands } from "./interface.js";
import { DebianCommands } from "./debian.js";
import { RHELCommands } from "./rhel.js";
import { logger } from "../../logger.js";

/** Create the correct DistroCommands implementation for the detected distro. */
export function createDistroCommands(distro: DistroContext): DistroCommands {
  switch (distro.family) {
    case "debian": return new DebianCommands();
    case "rhel": return new RHELCommands();
    default:
      // Debian fallback for unrecognized distro families (e.g., Arch, Alpine, NixOS).
      // The server stays runnable, but apt/dpkg commands will fail on non-Debian systems.
      // Operators should see this warning in logs; affected tools will return COMMAND_FAILED.
      logger.warn(
        { distroFamily: distro.family, distroName: distro.name },
        "Unrecognized distro family — falling back to Debian commands. Package/service tools may fail.",
      );
      return new DebianCommands();
  }
}
