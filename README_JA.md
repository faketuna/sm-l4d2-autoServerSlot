# Auto server slot

[[English]](README.md) [日本語]

## 注意

[LEFT12DEAD](https://forums.alliedmods.net/showthread.php?t=126857) の様な生存者のスポーンを自動化するプラグインはこのプラグインと競合するため、同時に導入しないでください。

このプラグインのコンパイルには[multicolors](https://github.com/Bara/Multi-Colors)が必要です。
## 機能

* 接続人数に応じて生存者の数を動的に変更する
* 接続人数に応じてサーバーのスロットを動的に変更する
* プレイヤーが接続した際に生存者botを新しく生成する
* 自分からdisconnectしたプレイヤーのbotをキックする (オプション機能)
* [Medkit density](https://forums.alliedmods.net/showpost.php?p=2745397&postcount=5)がインストールされている場合は、サーバー内の人数に応じてメディキットの数を動的に調整します。

## 依存関係

* [l4dtoolz](https://github.com/Accelerator74/l4dtoolz/releases)

## 依存関係 (任意)

* [Medkit density](https://forums.alliedmods.net/showpost.php?p=2745397&postcount=5)

## ConVar

* `sm_aslot_version` - プラグインのバージョン
* `sm_aslot_debug` - `0/1` - デバッグメッセージの切り替え
* `sm_aslot_kick` - `0/1` - 自動キックの切り替え。 もしも生存者の数が5人以上だった時のみ動作します。 4人以下にはなりません。
* `sm_aslot_fixed_survivor_limit` - `-1~32` - survivor_limit cvarをこのcvarの値で固定します。 -1にすると人数に応じて動的に変更するようになりますが、バグがあるためおすすめしません。
* `sm_aslot_fixed_server_slot` - `-1~32` - sv_maxplayers cvarをこのcvarの値で固定します。 -1にすると現在のプレイヤー + 1という形で動的にsv_maxplayersの値を変更します。