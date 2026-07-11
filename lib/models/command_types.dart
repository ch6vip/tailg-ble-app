enum CommandCode {
  lock('01', '设防'),
  unlock('02', '解锁'),
  openSeat('05', '开座桶'),
  powerOn('06', '启动'),
  powerOff('07', '熄火'),
  find('08', '寻车');

  final String code;
  final String label;
  const CommandCode(this.code, this.label);
}
