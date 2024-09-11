# Usage

## tmux session

首先，创建 tmux 会话，由于 pveproxy 创建的子进程使用 `www-data` 用户运行，因此使用 `www-data` 用户创建 tmux 会话，否则可能没有权限访问 `/tmp/tmux-*/` 目录：

```sh
$ sudo -u www-data tmux
```

## perl debug

```sh
$ git clone https://github.com/runsisi/Debug-Fork-Tmux.git
```

然后，在新的 SSH 会话中启动 perl 调试进程：

```sh
$ sudo perl -IDebug-Fork-Tmux -MDebug::Fork::Tmux -d /usr/bin/pveproxy start -debug
  DB<1> b /usr/share/perl5/PVE/APIServer/AnyEvent.pm:716
  DB<2> c
```

最后，回到 tmux 会话窗口进行调试操作。

# Dependencies

https://metacpan.org/pod/Debug::Fork::Tmux

https://metacpan.org/pod/Const::Fast

https://metacpan.org/pod/Env::Path

https://metacpan.org/pod/Sub::Exporter::Progressive

# Tmux Cheat Sheet

[Tmux Cheat Sheet & Quick Reference](https://tmuxcheatsheet.com/)

# References

[How to debug Perl scripts that fork](https://stackoverflow.com/questions/4211658/how-to-debug-perl-scripts-that-fork)

[Debugging Several Proccesses at Same Time](https://www.perlmonks.org/?node_id=128283)

[how to give access to my tmux session?](https://askubuntu.com/questions/1515906/how-to-give-access-to-my-tmux-session)
