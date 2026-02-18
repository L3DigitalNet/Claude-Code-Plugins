import type { DistroContext } from "../../types/distro.js";
import type { DistroCommands } from "./interface.js";
import { DebianCommands } from "./debian.js";
import { RHELCommands } from "./rhel.js";

/** Create the correct DistroCommands implementation for the detected distro. */
export function createDistroCommands(distro: DistroContext): DistroCommands {
  switch (distro.family) {
    case "debian": return new DebianCommands();
    case "rhel": return new RHELCommands();
    default: return new DebianCommands(); // safe fallback
  }
}
