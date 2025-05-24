// server_cli.cpp ─ Bash “server” launcher rebuilt in cross-platform C++17
//
// Build on Linux/macOS : g++ -std=c++17 -O2 server_cli.cpp -o server_cli
// Build on Windows     : cl /EHsc /std:c++17 server_cli.cpp && server_cli.exe
//
// ─────────────────────────────────────────────────────────────────────────────
#include <algorithm>
#include <array>
#include <cstdio>        // popen / pclose
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits.h>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#ifdef _WIN32
#  include <windows.h>
#else
#  include <sys/stat.h>
#  include <sys/types.h>
#  include <unistd.h>
#endif

namespace fs = std::filesystem;
using namespace std::string_literals;

// ─────────────────────────────────────────────────────────────────────────────
// Small util namespace
// ─────────────────────────────────────────────────────────────────────────────
namespace util {

inline std::string exec_dir() {
#ifdef _WIN32
  char buf[MAX_PATH];
  GetModuleFileNameA(nullptr, buf, MAX_PATH);
  return fs::path{buf}.parent_path().string();
#else
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif
  char buf[PATH_MAX];
  ssize_t len = ::readlink("/proc/self/exe", buf, sizeof(buf) - 1);
  if (len == -1) return ".";
  buf[len] = '\0';
  return fs::path{buf}.parent_path().string();
#endif
}

inline std::string color(const char *code) {
#ifdef _WIN32
  static bool enabled = [] {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD mode{};
    if (GetConsoleMode(h, &mode))
      SetConsoleMode(h, mode | 0x0004); // ENABLE_VIRTUAL_TERMINAL_PROCESSING
    return true;
  }();
  (void)enabled;
#endif
  return std::string("\033[") + code + 'm';
}

inline int sys(const std::string &cmd) { return std::system(cmd.c_str()); }

inline std::string join(const std::vector<std::string> &v,
                        std::string_view sep) {
  std::ostringstream out;
  for (size_t i = 0; i < v.size(); ++i) {
    if (i) out << sep;
    out << v[i];
  }
  return out.str();
}

inline void ensure_file(const fs::path &p) {
  if (!fs::exists(p)) {
    fs::create_directories(p.parent_path());
    std::ofstream{p};
  }
}

inline void update_env(const fs::path &file, const std::string &key,
                       const std::string &val) {
  ensure_file(file);
  std::ifstream in(file);
  std::stringstream tmp;
  const std::regex re("^#? *" + key + "=.*$");
  bool matched = false;
  std::string line;
  while (std::getline(in, line)) {
    if (std::regex_match(line, re)) {
      tmp << key << '=' << val << '\n';
      matched = true;
    } else
      tmp << line << '\n';
  }
  if (!matched) tmp << key << '=' << val << '\n';
  in.close();
  std::ofstream(file, std::ios::trunc) << tmp.str();
}

} // namespace util

// ───────────────────── Colours ─────────────────────
static const std::string RED    = util::color("0;31");
static const std::string GREEN  = util::color("0;32");
static const std::string CYAN   = util::color("0;36");
static const std::string YELLOW = util::color("1;33");
static const std::string NC     = util::color("0");

// ─────────────────── Path bundle ───────────────────
struct Paths {
  fs::path dir       = util::exec_dir();
  fs::path cfg       = dir / "docker";
  fs::path envMain   = dir / ".env";
  fs::path envDock   = cfg / ".env";
  fs::path compose   = cfg / "compose/main.yaml";
  fs::path utilities = cfg / "utilities";
};

// ───────────────────── CLI class ───────────────────
class ServerCLI {
public:
  explicit ServerCLI(const Paths &p) : paths(p) {}
  int run(int argc, char **argv);

private:
  Paths paths;

// helpers
  static std::string lower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    return s;
  }
  static bool is_perms(const char *s) {
    std::string t = lower(s);
    return t == "permission" || t == "permissions" || t == "perms" ||
           t == "perm";
  }

  // docker /compose wrappers
  int compose(std::vector<std::string> args,
              std::vector<std::string> extra = {});
  int docker_exec(const std::vector<std::string> &a);

  // big tasks
  int restart();
  int http_reload();
  int env_init();
  int env_edit();
  int fix_perms();
  int install_ca();
  int mkhost(const std::vector<std::string> &args);
  int setup_domain();
  int modify_profiles(const std::string &action,
                      const std::vector<std::string> &profiles);
  int process_all_profiles();
  int launch_php(const std::string &domain);

  // utilities
  static std::string capture_cmd_output(const std::string &cmd);
  bool script_passthrough(int argc, char **argv);
  static long getuid_safe();
  static long getgid_safe();
  static std::string detect_timezone();
  int help();
};

// ───────────────── Docker helpers ──────────────────
int ServerCLI::compose(std::vector<std::string> args,
                       std::vector<std::string> extra) {
  std::vector<std::string> cmd = {
      "docker", "compose", "--project-directory", paths.dir.string(),
      "-f",     paths.compose.string(), "--env-file", paths.envDock.string()};
  cmd.insert(cmd.end(), args.begin(), args.end());
  cmd.insert(cmd.end(), extra.begin(), extra.end());
  return util::sys(util::join(cmd, " "));
}

int ServerCLI::docker_exec(const std::vector<std::string> &a) {
  std::vector<std::string> cmd = {"docker"};
  cmd.insert(cmd.end(), a.begin(), a.end());
  return util::sys(util::join(cmd, " "));
}

// ───────────── Restart & HTTP reload ──────────────
int ServerCLI::restart() {
  if (int rc = compose({"down"}); rc) return rc;
  if (int rc = compose({"up", "-d"}); rc) return rc;
  return http_reload();
}

int ServerCLI::http_reload() {
  std::cout << GREEN << "Reloading HTTP…" << NC << '\n';
  util::sys("docker ps -qf name=NGINX >/dev/null 2>&1 && "
            "docker exec NGINX nginx -s reload || true");
  util::sys("docker ps -qf name=APACHE >/dev/null 2>&1 && "
            "docker exec APACHE apachectl graceful || true");
  std::cout << GREEN << "HTTP reloaded" << NC << '\n';
  return 0;
}

// ─────────────── Environment init ────────────────
int ServerCLI::env_init() {
  auto ask = [&](const std::string &prompt, const std::string &def) {
    std::cout << CYAN << prompt << " [default: " << def << "]: " << NC;
    std::string in;
    std::getline(std::cin, in);
    return in.empty() ? def : in;
  };
  std::cout << YELLOW << "Bootstrapping environment defaults…" << NC << '\n';
  std::string tz   = ask("Timezone (TZ)", detect_timezone());
  std::string user = ask("User", getenv("USER") ? getenv("USER") : "user");
  std::string uid  = ask("User UID", std::to_string(getuid_safe()));
  std::string gid  = ask("User GID", std::to_string(getgid_safe()));

  util::update_env(paths.envDock, "TZ",   tz);
  util::update_env(paths.envDock, "USER", user);
  util::update_env(paths.envDock, "UID",  uid);
  util::update_env(paths.envDock, "GID",  gid);

  std::cout << GREEN << "Defaults saved!" << NC << '\n';
  return 0;
}

int ServerCLI::env_edit() {
#ifdef _WIN32
  std::cerr << RED << "`env edit` not supported on Windows." << NC << '\n';
  return 1;
#else
  const char *ed = getenv("EDITOR");
  if (!ed) ed = "nano";
  return util::sys(std::string(ed) + " " + paths.envDock.string());
#endif
}

// ───────────── Permission fixer (POSIX) ───────────
int ServerCLI::fix_perms() {
#ifdef _WIN32
  std::cout << YELLOW << "Skipping permission fix on Windows." << NC << '\n';
  return 0;
#else
  if (getuid() != 0) {
    std::cerr << RED << "Please run with sudo." << NC << '\n';
    return 1;
  }

  std::vector<std::string> cmds = {
      "chmod 755 '" + paths.dir.string() + "'",
      "chmod 2775 '" + (paths.dir / "configuration").string() + "'",
      "find '" + (paths.dir / "configuration").string() +
          "' -type f ! -perm 664 -exec chmod 664 {} +",
      "chmod 755 '" + paths.cfg.string() + "'",
      "find '" + paths.cfg.string() +
          "' -type f ! -perm 644 -exec chmod 644 {} +",
      "chmod 2777 '" + (paths.dir / "data").string() + "'",
      "find '" + (paths.dir / "data").string() +
          "' -mindepth 1 -maxdepth 1 -type d -exec chmod 2777 {} +",
      "find '" + (paths.dir / "data").string() +
          "' -type f -exec chmod 666 {} +",
      "chmod -R 777 '" + (paths.dir / "logs").string() + "'",
      "chown -R '" +
          std::string(getenv("SUDO_USER") ? getenv("SUDO_USER") : "root") +
          ":docker' '" + (paths.dir / "logs").string() + "' || true",
      "chmod 755 '" + (paths.dir / "bin").string() + "'",
      "find '" + (paths.dir / "bin").string() +
          "' -type f ! -name '*.bat' -exec chmod 744 {} +",
      "chmod 744 '" + (paths.dir / "server").string() +
          "' 2>/dev/null || true",
      "ln -fs '" + (paths.dir / "server").string() +
          "' /usr/local/bin/server"};

  for (const auto &c : cmds)
    util::sys(c + " >/dev/null 2>&1");

  std::cout << GREEN << "Permissions assigned." << NC << '\n';
  return 0;
#endif
}

// ─────────────── Root-CA install ────────────────
int ServerCLI::install_ca() {
  fs::path src = paths.dir / "configuration/rootCA/rootCA.pem";
#ifdef _WIN32
  std::cerr << YELLOW
            << "Auto CA install not implemented on Windows.\nImport "
            << src << " manually." << NC << '\n';
  return fs::exists(src) ? 0 : 1;
#else
  fs::path dest = "/usr/local/share/ca-certificates/rootCA.crt";
  if (getuid() != 0) {
    std::cerr << RED << "install certificate requires sudo." << NC << '\n';
    return 1;
  }
  if (!fs::exists(src)) {
    std::cerr << RED << "certificate not found: " << src << NC << '\n';
    return 1;
  }
  fs::copy_file(src, dest, fs::copy_options::overwrite_existing);
  util::sys("update-ca-certificates");
  util::sys("trust extract-compat >/dev/null 2>&1 || true");
  std::cout << GREEN << "Root CA installed → " << dest << NC << '\n';
  return 0;
#endif
}

// ─────────────── Domain helpers ────────────────
int ServerCLI::mkhost(const std::vector<std::string> &args) {
  std::vector<std::string> cmd = {"docker", "exec", "SERVER_TOOLS", "mkhost"};
  cmd.insert(cmd.end(), args.begin(), args.end());
  return util::sys(util::join(cmd, " "));
}

int ServerCLI::modify_profiles(
    const std::string &action, const std::vector<std::string> &profiles) {
  const std::string var = "COMPOSE_PROFILES";
  util::ensure_file(paths.envDock);

  // get existing
  std::ifstream in(paths.envDock);
  std::string line, val;
  while (std::getline(in, line))
    if (line.rfind(var + '=', 0) == 0) val = line.substr(var.size() + 1);

  std::set<std::string> set;
  if (!val.empty()) {
    std::stringstream ss(val);
    std::string tok;
    while (std::getline(ss, tok, ',')) set.insert(tok);
  }

  if (action == "add")
    set.insert(profiles.begin(), profiles.end());
  else if (action == "remove")
    for (const auto &p : profiles) set.erase(p);
  else {
    std::cerr << RED << "modify_profiles: invalid action" << NC << '\n';
    return 1;
  }

  util::update_env(paths.envDock, var,
                   util::join(std::vector<std::string>(set.begin(), set.end()),
                              ","));
  return 0;
}

int ServerCLI::setup_domain() {
  mkhost({"--RESET"});
  util::sys("docker exec -it SERVER_TOOLS mkhost");

  std::string php_prof =
      capture_cmd_output("docker exec SERVER_TOOLS mkhost --ACTIVE_PHP_PROFILE");
  std::string svr_prof =
      capture_cmd_output("docker exec SERVER_TOOLS mkhost --APACHE_ACTIVE");

  if (!php_prof.empty()) modify_profiles("add", {php_prof});
  if (!svr_prof.empty()) modify_profiles("add", {svr_prof});
  mkhost({"--RESET"});
  return 0;
}

int ServerCLI::process_all_profiles() {
  fs::path script = paths.utilities / "profiles";
  if (!fs::exists(script)) {
    std::cerr << RED << "utilities/profiles not found" << NC << '\n';
    return 1;
  }
  return util::sys(script.string());
}

// ─────── Launch PHP container inside docroot ─────
int ServerCLI::launch_php(const std::string &domain) {
  fs::path nconf = paths.dir / "configuration/nginx" / (domain + ".conf");
  fs::path aconf = paths.dir / "configuration/apache" / (domain + ".conf");
  if (!fs::exists(nconf)) {
    std::cerr << RED << "No Nginx config for " << domain << NC << '\n';
    return 1;
  }

  std::string php, docroot;
  {
    std::ifstream f(nconf);
    std::string line;
    std::regex fast("fastcgi_pass ([^:]+):9000");
    std::regex root("root ([^;]+)");
    while (std::getline(f, line)) {
      std::smatch m;
      if (php.empty() && std::regex_search(line, m, fast)) php = m[1];
      if (docroot.empty() && std::regex_search(line, m, root)) docroot = m[1];
    }
  }

  if (php.empty() && fs::exists(aconf)) {
    std::ifstream f(aconf);
    std::string line;
    std::regex proxy("proxy:fcgi://([^:]+):9000");
    std::regex doc("DocumentRoot ([^ ]+)");
    while (std::getline(f, line)) {
      std::smatch m;
      if (docroot.empty() && std::regex_search(line, m, doc)) docroot = m[1];
      if (php.empty() && std::regex_search(line, m, proxy)) php = m[1];
    }
  }

  if (php.empty()) {
    std::cerr << RED << "Could not detect PHP container." << NC << '\n';
    return 1;
  }
  if (docroot.empty()) docroot = "/app";

  for (const std::string s : {"public", "dist", "public_html"}) {
    if (docroot.size() > s.size() + 1 &&
        docroot.compare(docroot.size() - s.size(), s.size(), s) == 0 &&
        docroot[docroot.size() - s.size() - 1] == '/') {
      docroot.erase(docroot.size() - s.size() - 1);
      break;
    }
  }

  std::vector<std::string> cmd = {"docker", "exec", "-it", php, "bash",
                                  "--login", "-c",
                                  "cd '" + docroot + "' && exec bash"};
  return util::sys(util::join(cmd, " "));
}

// ───────── Capture shell command output (POSIX) ─────────
std::string ServerCLI::capture_cmd_output(const std::string &cmd) {
#ifdef _WIN32
  return "";
#else
  std::array<char, 256> buf{};
  std::string out;
  FILE *p = popen(cmd.c_str(), "r");
  if (!p) return "";
  while (fgets(buf.data(), buf.size(), p)) out += buf.data();
  pclose(p);
  out.erase(std::remove(out.begin(), out.end(), '\n'), out.end());
  return out;
#endif
}

// ───────────── Script passthrough to bin/* ─────────────
bool ServerCLI::script_passthrough(int argc, char **argv) {
  static const std::set<std::string> names = {
      "php",  "mariadb",      "mariadb-dump", "mysql",  "mysql-dump",
      "psql", "pg_dump",      "pg_restore",   "redis",  "composer"};
  if (argc < 2) return false;
  if (!names.count(argv[1])) return false;

  fs::path script = paths.dir / "bin" / argv[1];
  if (!fs::exists(script)) {
    std::cerr << RED << "Script not found: " << script << NC << '\n';
    return true;
  }
  std::vector<std::string> cmd = {script.string()};
  for (int i = 2; i < argc; ++i) cmd.emplace_back(argv[i]);
  util::sys(util::join(cmd, " "));
  return true;
}

// ─────────── Small wrappers for UID/GID ───────────
long ServerCLI::getuid_safe() {
#ifdef _WIN32
  return 0;
#else
  return ::getuid();
#endif
}

long ServerCLI::getgid_safe() {
#ifdef _WIN32
  return 0;
#else
  return ::getgid();
#endif
}

// ───────────── Auto-detect local timezone ──────────
std::string ServerCLI::detect_timezone() {
#ifdef _WIN32
  return "UTC";
#else
  if (util::sys("timedatectl >/dev/null 2>&1") == 0)
    return capture_cmd_output(
        "timedatectl show -p Timezone --value");
  if (const char *tz = getenv("TZ"); tz && *tz) return tz;
  if (fs::exists("/etc/timezone")) {
    std::ifstream f("/etc/timezone");
    std::string s;
    std::getline(f, s);
    return s;
  }
  return "UTC";
#endif
}

// ──────────────────── Help text ───────────────────
int ServerCLI::help() {
  std::cout << CYAN << "Usage:" << NC
            << " server <command> [options]\n\n"
            << CYAN << "Core commands:" << NC << '\n'
            << "  up | start                 Start docker stack (foreground)\n"
            << "  stop | down                Stop stack\n"
            << "  reload | restart           Restart stack + reload HTTP\n"
            << "  rebuild [services…]        Rebuild images (no cache)\n"
            << "  config                     Validate compose file\n"
            << "  http reload                Reload Nginx/Apache\n"
            << "  core <domain>              Open bash in PHP container\n"
            << "  tools                      Enter SERVER_TOOLS container\n"
            << "  lzd | lazydocker           LazyDocker inside SERVER_TOOLS\n\n"
            << CYAN << "Setup commands:" << NC << '\n'
            << "  setup permissions          Fix file/directory perms (POSIX)\n"
            << "  setup domain               Run mkhost & profile sync\n"
            << "  setup profiles             utilities/profiles script\n\n"
            << CYAN << "Env commands:" << NC << '\n'
            << "  env init|boot              Bootstrap TZ/USER/UID/GID\n"
            << "  env edit                   Open docker/.env in $EDITOR\n\n"
            << CYAN << "Misc:" << NC << '\n'
            << "  install certificate        Install project rootCA\n"
            << "  help                       This screen\n";
  return 0;
}

// ─────────────── Main dispatcher ────────────────
int ServerCLI::run(int argc, char **argv) {
  if (argc < 2) return help();
  if (script_passthrough(argc, argv)) return 0;

  std::string cmd = lower(argv[1]);
  if (cmd == "up")         return compose({"up"});
  if (cmd == "start")         return compose({"up", "-d"});
  if (cmd == "stop" || cmd == "down")        return compose({"down"});
  if (cmd == "reload" || cmd == "restart")   return restart();
  if (cmd == "rebuild")                return compose(
          {"build", "--no-cache", "--pull"},
          std::vector<std::string>(argv + 2, argv + argc));
  if (cmd == "config")                  return compose({"config"});
  if (cmd == "http" && argc > 2 && std::string(argv[2]) == "reload")
    return http_reload();
  if (cmd == "setup" && argc > 2 && is_perms(argv[2])) return fix_perms();
  if (cmd == "setup" && argc > 2 && std::string(argv[2]) == "domain")
    return setup_domain();
  if (cmd == "setup" && argc > 2 &&
      (argv[2] == std::string("profiles") || argv[2] == std::string("profile")))
    return process_all_profiles();
  if (cmd == "install" && argc > 2 && std::string(argv[2]) == "certificate")
    return install_ca();
  if (cmd == "env" && argc > 2 &&
      (argv[2] == std::string("init") || argv[2] == std::string("boot")))
    return env_init();
  if (cmd == "env" && argc > 2 && std::string(argv[2]) == "edit")
    return env_edit();
  if (cmd == "core" && argc > 2)        return launch_php(argv[2]);
  if (cmd == "tools")                   return docker_exec(
          {"exec", "-it", "SERVER_TOOLS", "bash"});
  if (cmd == "lzd" || cmd == "lazydocker")
    return docker_exec({"exec", "-it", "SERVER_TOOLS", "lazydocker"});
  if (cmd == "help") return help();

  std::cerr << RED << "Unknown command: " << cmd << NC << "\n\n";
  return help();
}

// ─────────────────────── main() ──────────────────
int main(int argc, char **argv) {
  try {
    Paths p;
    return ServerCLI(p).run(argc, argv);
  } catch (const std::exception &e) {
    std::cerr << RED << "Fatal: " << e.what() << NC << '\n';
    return 1;
  }
}
