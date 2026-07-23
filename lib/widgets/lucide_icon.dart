import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Thin wrapper so every icon call site goes through Lucide.
///
/// Prefer [Lucide.xxx] / [LucideIcon] over raw [LucideIcons] in page code.
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}

/// Canonical icon map for the Tailg VOID shell.
///
/// Pages should import this file and use [Lucide.xxx] — never Material Icons.
/// Backed by package:flutter_lucide (snake_case IconData constants).
abstract final class Lucide {
  static const service = LucideIcons.layout_grid;
  static const vehicle = LucideIcons.bike;
  static const mine = LucideIcons.user;
  static const settings = LucideIcons.settings;
  static const chevronRight = LucideIcons.chevron_right;
  static const chevronDown = LucideIcons.chevron_down;
  static const chevronLeft = LucideIcons.chevron_left;
  static const arrowLeft = LucideIcons.arrow_left;
  static const mapPin = LucideIcons.map_pin;
  static const route = LucideIcons.git_branch;
  static const fence = LucideIcons.shield;
  static const battery = LucideIcons.battery_charging;
  static const batteryFull = LucideIcons.battery_full;
  static const chart = LucideIcons.chart_column;
  static const tune = LucideIcons.sliders_horizontal;
  static const more = LucideIcons.layout_list;
  static const find = LucideIcons.radio;
  static const lock = LucideIcons.lock;
  static const unlock = LucideIcons.lock_open;
  static const power = LucideIcons.power;
  static const seat = LucideIcons.package_open;
  static const bluetooth = LucideIcons.bluetooth;
  static const bluetoothOff = LucideIcons.bluetooth_off;
  static const wifi = LucideIcons.wifi;
  static const cloud = LucideIcons.cloud;
  static const channel = LucideIcons.git_branch;
  static const message = LucideIcons.bell;
  static const help = LucideIcons.circle_question_mark;
  static const info = LucideIcons.info;
  static const about = LucideIcons.badge_info;
  static const garage = LucideIcons.warehouse;
  static const login = LucideIcons.log_in;
  static const logout = LucideIcons.log_out;
  static const phone = LucideIcons.phone;
  static const key = LucideIcons.key_round;
  static const scan = LucideIcons.scan_line;
  static const plus = LucideIcons.plus;
  static const check = LucideIcons.check;
  static const x = LucideIcons.x;
  static const alert = LucideIcons.triangle_alert;
  static const zap = LucideIcons.zap;
  static const activity = LucideIcons.activity;
  static const compass = LucideIcons.compass;
  static const shield = LucideIcons.shield;
  static const pulse = LucideIcons.heart_pulse;
  static const refresh = LucideIcons.refresh_cw;
  static const copy = LucideIcons.copy;
  static const eye = LucideIcons.eye;
  static const eyeOff = LucideIcons.eye_off;
  static const link = LucideIcons.link;
  static const unplug = LucideIcons.unplug;
  static const spark = LucideIcons.sparkles;
  static const layers = LucideIcons.layers;
  static const wrench = LucideIcons.wrench;
  static const stethoscope = LucideIcons.stethoscope;
  static const userCircle = LucideIcons.circle_user;
  static const home = LucideIcons.house;
  static const checkCircle = LucideIcons.circle_check;
  static const plusCircle = LucideIcons.circle_plus;
  static const bluetoothSearching = LucideIcons.bluetooth_searching;
  static const stop = LucideIcons.circle_stop;
  static const languages = LucideIcons.languages;
  static const ruler = LucideIcons.ruler;
  static const type = LucideIcons.type;
  static const shieldCheck = LucideIcons.shield_check;
  static const fileText = LucideIcons.file_text;
  static const mail = LucideIcons.mail;
  static const megaphone = LucideIcons.megaphone;
  static const batteryWarning = LucideIcons.battery_warning;
  static const list = LucideIcons.list;
  static const edit = LucideIcons.square_pen;
  static const pointer = LucideIcons.pointer;
  static const thermometer = LucideIcons.thermometer;
  static const gauge = LucideIcons.gauge;
  static const rotateCcw = LucideIcons.rotate_ccw;
  static const clipboard = LucideIcons.clipboard;
  static const clipboardPaste = LucideIcons.clipboard_paste;
  static const map = LucideIcons.map;
  static const navigation = LucideIcons.navigation;
  static const locate = LucideIcons.locate;
  static const wifiOff = LucideIcons.wifi_off;
  static const unlink = LucideIcons.unlink;
  static const trash = LucideIcons.trash_2;
  static const badgeCheck = LucideIcons.badge_check;
  static const alertCircle = LucideIcons.circle_alert;
  static const briefcase = LucideIcons.briefcase;
  static const radar = LucideIcons.radar;
  static const pin = LucideIcons.pin;
  static const gamepad = LucideIcons.gamepad_2;
  static const sensors = LucideIcons.radio;
  static const control = LucideIcons.crosshair;
  static const nfc = LucideIcons.nfc;
  static const history = LucideIcons.history;
  static const creditCard = LucideIcons.credit_card;
  static const watch = LucideIcons.watch;
  static const smartphone = LucideIcons.smartphone;
  static const userPlus = LucideIcons.user_plus;
  static const share = LucideIcons.share_2;
  static const save = LucideIcons.save;
  static const calendar = LucideIcons.calendar;
  static const bookmark = LucideIcons.bookmark;
  static const clipboardList = LucideIcons.clipboard_list;
  static const ticket = LucideIcons.ticket;
  static const leaf = LucideIcons.leaf;
  static const headphones = LucideIcons.headphones;
  static const users = LucideIcons.users;
  static const userX = LucideIcons.user_x;
  static const search = LucideIcons.search;
  static const circle = LucideIcons.circle;
  static const circleDot = LucideIcons.circle_dot;
  static const wallet = LucideIcons.wallet;
  static const calendarCheck = LucideIcons.calendar_check;
  static const receipt = LucideIcons.receipt;
  static const ban = LucideIcons.ban;
  static const upload = LucideIcons.upload;
  static const scrollText = LucideIcons.scroll_text;
  static const lifeBuoy = LucideIcons.life_buoy;
  static const messageCircle = LucideIcons.message_circle;
  static const radioTower = LucideIcons.radio_tower;
  static const chartBar = LucideIcons.chart_column;
  static const cloudOff = LucideIcons.cloud_off;
  static const keyOff = LucideIcons.ban;
  static const support = LucideIcons.headphones;
  static const privacy = LucideIcons.shield_check;
  static const radioUnchecked = LucideIcons.circle;
  static const tripOrigin = LucideIcons.circle_dot;
  static const explore = LucideIcons.compass;
  static const locationSearching = LucideIcons.crosshair;
  static const groupOff = LucideIcons.user_x;
  static const arrowDown = LucideIcons.chevron_down;
  static const download = LucideIcons.download;
}
