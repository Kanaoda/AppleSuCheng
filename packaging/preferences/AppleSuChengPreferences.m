#import "AppleSuChengPreferences.h"

@implementation AppleSuChengPreferences

- (NSView *)loadMainView {
  const CGFloat width = 468.0;
  const CGFloat height = 360.0;
  NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];

  NSTextField *title = [NSTextField labelWithString:@"蘋果速成"];
  title.font = [NSFont boldSystemFontOfSize:15];
  title.textColor = [NSColor labelColor];
  title.frame = NSMakeRect(20, height - 36, width - 40, 22);
  [root addSubview:title];

  NSTextField *subtitle = [NSTextField wrappingLabelWithString:
    @"與原機「速成 – Traditional」相同字根排列。系統「加入輸入法」對話框對第三方輸入法無法顯示鍵盤預覽，因此在此提供。"];
  subtitle.font = [NSFont systemFontOfSize:11];
  subtitle.textColor = [NSColor secondaryLabelColor];
  subtitle.frame = NSMakeRect(20, height - 88, width - 40, 48);
  [root addSubview:subtitle];

  NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(14, 56, width - 28, 200)];
  imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
  imageView.imageAlignment = NSImageAlignCenter;
  NSString *imgPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"keyboard_preview" ofType:@"png"];
  if (imgPath) {
    imageView.image = [[NSImage alloc] initWithContentsOfFile:imgPath];
  }
  [root addSubview:imageView];

  NSTextField *hint = [NSTextField wrappingLabelWithString:
    @"提示：Shift+數字選聯想、空白鍵翻頁；單碼字根直接空白上屏。"];
  hint.font = [NSFont systemFontOfSize:11];
  hint.textColor = [NSColor tertiaryLabelColor];
  hint.frame = NSMakeRect(20, 16, width - 40, 36);
  [root addSubview:hint];

  self.mainView = root;
  return root;
}

@end
