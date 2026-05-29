// Shell 隐藏接口，定义在公共位置，让 main_scaffold 和 state_perception_page 共享同一个类型
abstract class ShellHideNotifier {
  void setHide(bool hide);
}
