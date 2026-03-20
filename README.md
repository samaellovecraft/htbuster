# HTBuster

A state-aware, POSIX-compliant shell engine for managing Hack The Box (HTB) lab directory structures and lifecycle. 

Instead of manually creating directories or writing clunky sub-process Python scripts that can't natively update your shell's working directory, this tool runs entirely in-memory as a set of shell functions. It handles scaffolding, traversal, and state lifecycle (`Active` to `Retired`) with built-in security guards.

HTBuster enforces a rigid, three-tier hierarchy to mirror the platform's state. By separating boxes by category and lifecycle, the engine eliminates directory sprawl and ensures your local lab remains navigable over long-term practice sessions.

<details>
<summary><b>Table of Contents</b></summary>

- [Features](#features)
- [Lab Layout](#lab-layout)
- [Installation](#installation)
- [Usage](#usage)
- [Architecture Notes](#architecture-notes)

</details>

## Features

* **Instant Scaffolding & Traversal:** Run `htbma [box]` to instantly build the directory structure and `cd` into it. If it already exists, you just jump there.
* **Intelligent Collision Detection:** Trying to create an `Active` box that already exists in `Retired`? The engine detects the orphaned state and redirects you to the existing directory rather than overwriting it.
* **State-Aware Retirement:** Run `htbretire <box>`. The engine moves the directory to the corresponding `Retired` folder and safely transplants your current shell session to the new path so you aren't left in a ghost inode. 
* **TTY-Gated Prompts:** Uses POSIX `read < /dev/tty` to prevent rogue piped inputs from bypassing confirmation prompts. 

## Lab Layout

The root directory (`$HTB_ROOT`) is partitioned into three primary categories:
```text
HTB
├── Challenges
│   ├── Active
│   └── Retired
├── Machines
│   ├── Active
│   └── Retired
└── Sherlocks
    ├── Active
    └── Retired
```

### Directory Structures

The engine also enforces consistent file trees based on the box category:

#### Machines

```text
.
├── artifacts   # Local loot
├── attachments # Screenshots
├── enumeration # Scans and raw output
└── README.md   # Notes template
```

#### Challenges & Sherlocks

```text
.
├── artifacts   # Local loot
├── attachments # Screenshots
└── README.md   # Notes
```

## Installation

1. Download the script to your home directory (or anywhere you keep your scripts):
```sh
curl -o ~/.htbuster https://raw.githubusercontent.com/samaellovecraft/HTBuster/main/htbuster.sh 
```
2. Source it in your shell profile (`~/.zshrc` or `~/.bashrc`):
```sh 
echo '[[ -f ~/.htbuster ]] && source ~/.htbuster' >> ~/.zshrc
source ~/.zshrc
```

> [!IMPORTANT]
> By default, the engine assumes your lab is located at `$HOME/HTB`. You can override this by setting the `$LAB` environment variable in your `.zshrc` or `.zshenv` before sourcing the script:
> ```sh
> export LAB="/path/to/your/lab"
> ```

## Usage

Commands follow a consistent mnemonic pattern: `htb` + `<category>` + `<state>`.

* **Categories:** `m` (Machines), `ch` (Challenges), `sh` (Sherlocks)
* **States:** `a` (Active), `r` (Retired)

<details>
<summary><b>View Full Command Reference Table</b></summary>

| Command           | State   | Resulting Action                                                   |
| :---------------- | :------ | :----------------------------------------------------------------- |
| `htbma`           | Active  | `cd $HTB_ROOT/Machines/Active`                                     |
| `htbma [box]`     | Active  | Create/Jump to `$HTB_ROOT/Machines/Active/[box]`                   |
| `htbmr`           | Retired | `cd $HTB_ROOT/Machines/Retired`                                    |
| `htbmr [box]`     | Retired | Create/Jump to `$HTB_ROOT/Machines/Retired/[box]`                  |
| `htbcha`          | Active  | `cd $HTB_ROOT/Challenges/Active`                                   |
| `htbcha [box]`    | Active  | Create/Jump to `$HTB_ROOT/Challenges/Active/[box]`                 |
| `htbchr`          | Retired | `cd $HTB_ROOT/Challenges/Retired`                                  |
| `htbchr [box]`    | Retired | Create/Jump to `$HTB_ROOT/Challenges/Retired/[box]`                |
| `htbsha`          | Active  | `cd $HTB_ROOT/Sherlocks/Active`                                    |
| `htbsha [box]`    | Active  | Create/Jump to `$HTB_ROOT/Sherlocks/Active/[box]`                  |
| `htbshr`          | Retired | `cd $HTB_ROOT/Sherlocks/Retired`                                   |
| `htbshr [box]`    | Retired | Create/Jump to `$HTB_ROOT/Sherlocks/Retired/[box]`                 |
| `htbretire <box>` | Active  | Locate `<box>` in any `Active/` category and move it to `Retired/` |

</details>

### Base Navigation (No Arguments)

Running a command without a box name acts as a shortcut to the category's root directory:
```sh 
htbma  # cd $HTB_ROOT/Machines/Active
htbchr # cd $HTB_ROOT/Challenges/Retired
```

### Target Scaffolding & Jumping

Providing a box name triggers a search. If the box exists in the requested state, you `cd` into it. If it doesn't, the engine prompts to initialize the directory structure.

#### Example: Creating a new Machine

```text
$ htbma Box
[?] Creating /home/user/HTB/Machines/Active/Box. Proceed? [Y/n] y
[+] Initializing Box in Machines/Active...
[+] Ready.

$ pwd
/home/user/HTB/Machines/Active/Box

$ tree
.
├── artifacts
├── attachments
├── enumeration
└── README.md
```

### State-Aware Redirection

The engine prevents data duplication. If you attempt to access a box as `Active` but it already exists in the `Retired` path, HTBuster detects the collision and redirects your shell to the existing data.

#### Example: Accessing a box that has already been retired

```text
$ htbma Legacy
[!] 'Legacy' already exists in /home/user/HTB/Machines/Retired. Jumping there instead.

$ pwd
/home/user/HTB/Machines/Retired/Legacy
```

### Retiring a Box

When a Machine, Challenge, or Sherlock retires on the platform, run `htbretire <box>`. The engine will scan all `Active` categories for the box, move it to the corresponding `Retired` folder, and safely transplant your shell path if you are currently inside it.
```text
$ htbretire Box
[?] Retiring 'Box' to /home/user/HTB/Machines/Retired/. Proceed? [Y/n] y
[+] Retiring Box from Machines...

$ pwd
/home/user/HTB/Machines/Retired/Box
```

> [!TIP]
> Since the engine iterates through all high-order categories, `htbretire` is *location-agnostic*. You can trigger retirement from any directory without needing to navigate to the lab root first.

## Architecture Notes

* **`mv` Nesting Prevention:** A standard `mv dir1 dir2` will silently nest `dir1` inside `dir2` if `dir2/dir1` already exists. `htbretire` explicitly checks the target path first and aborts on collision to prevent mangling your lab archives.
* **TTY Sandboxing:** Interactive prompts enforce `read -r response < /dev/tty`. This prevents unintended execution if stdout/stdin is manipulated via pipes (e.g., `echo "payload" | htbretire`).
