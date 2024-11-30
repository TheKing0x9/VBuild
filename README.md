# VBuild

VBuild is a simple build system for Verilog projects. Simple. Fast. Extensible.

> VBuild is currently in early alpha, and is not recommended for production use. As the project matures, features can and will break.

## Installation

VBuild is distributed as an executable that can be downloaded from [releases](https://github.com/TheKing0x9/VBuild/releases). To install, simply download the executable and place it in your path.
Optionally, you may need to give the executable permission to run.

### Pre-requisites

At the moment, VBuild is only supported on Linux. Support for Windows is planned in the future.
Moreover, the C libraries are not bundled with the executable at the moment, so `luarocks` is required to install the mentioned dependencies.
This will be fixed in the next release.

Install `luarocks` and the required dependencies by running the following commands:

```bash
sudo apt-get install luarocks
luarocks install luafilesystem --local
luarocks install readline --local
luarocks install argparse --local
```

## Usage

Stock VBuild is shipped only with the capability to scan and monitor project directories for changes.
Additional features are implemented via plugins, which add features like compiling Verilog and VHDL files, running testbenches, and more.

Running VBuild is as simple as running the executable from the project root:

```bash
vbuild
```

This will launch VBuild and start scanning the project directories for changes. Command for VBuild can then be entered in the REPL that starts.
```
vbuild> help
vbuild> build dadda11
```

## Configuration

VBuild uses a configuration file to specify the project settings which is a TOML script that is loaded by VBuild when it is run.
The configuration file is expected to be named `vbuild.config` and should be placed in the root of the project directory.

Stock VBuild is shipped with the following configuration options:

```toml
[General]
project_name = "Vertex Multiplier" # Name of the project, Metadata, Not used by VBuild
project_version = "0.1.0" # Version of the project, Metadata, Not used by VBuild

[Sources]
source_dirs = ["src"] # Directories containing source files, relative to the project root
testbench_dirs = ["testbenches"] # Directories containing testbenches, relative to the project root
iterative_scan = true # Whether to scan the source directories iteratively or not

[Plugins]
path = "plugins" # Path to the plugins directory, relative to the project root
autoload = false # Whether to autoload plugins or not
```

Plugins can register more configuration options, which are documented in the plugin's documentation.

## Building from Source

Building VBuild from source is a trivial task. All you need is `git`, `LuaJIT`, and `luarocks`.

Get started by installing `luarocks` and the required dependencies

```bash
sudo apt-get install luarocks
luarocks install readline --local
luarocks install argparse --local
luarocks install luastatic --local
luarocks install luafilesystem --local
```

Next, `LuaJIT` is required to build the executable. Since we need the static library for compiling `VBuild`, build `LuaJIT` by running the following commands:

```bash
git clone https:www.github.com/LuaJIT/LuaJIT
cd LuaJIT
make
```

Finally, clone the repository, update the path to the `LuaJIT` library in the Makefile, and run the `Makefile` to build the executable:

```bash
git clone https://www.github.com/theking0x9/vbuild
cd vbuild
make
```

If you encounter any issues, please open an issue on the repository.

## Planned Features

This is the first public release of VBuild. The following features are planned for future releases:

### Core

- [-] Add command line options for VBuild
- [ ] Add help for commands
- [ ] Expose hooks for file changes in the API
- [ ] Windows Port
- [ ] VHDL support
- [ ] Bundle C libraries with executable
- [ ] Include Verilog and VHDL AST parsers
- [ ] Explore Verilog Tasks and add support for them
- [ ] Add support for SystemVerilog

### Plugins

- [ ] Support plugin.onload and plugin.init functions
- [ ] Write a plugin to generate `vbuild.config` files
- [ ] Plugins manager for VBuild

### Documentation
- [ ] Write documentation for plugin development
- [ ] Document VBuild's internal API
