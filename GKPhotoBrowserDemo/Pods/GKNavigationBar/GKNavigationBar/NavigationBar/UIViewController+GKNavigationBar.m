//
//  UIViewController+GKNavigationBar.m
//  GKNavigationBarExample
//
//  Created by gaokun on 2020/10/29.
//  Copyright © 2020 QuintGao. All rights reserved.
//

#import "UIViewController+GKNavigationBar.h"
#import "GKNavigationBarDefine.h"

#if __has_include(<GKNavigationBar/GKGestureHandleDefine.h>)
#import <GKNavigationBar/GKGestureHandleDefine.h>
#elif __has_include("GKGestureHandleDefine.h")
#import "GKGestureHandleDefine.h"
#endif

#define HasGestureHandle (__has_include(<GKNavigationBar/GKGestureHandleDefine.h>) || __has_include("GKGestureHandleDefine.h"))

@interface UIViewController (GKNavigationBar)

/// 导航栏是否添加过
@property (nonatomic, assign) BOOL gk_navBarAdded;

@end

@implementation UIViewController (GKNavigationBar)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray <NSString *> *oriSels = @[@"viewDidLoad",
                                          @"viewWillAppear:",
                                          @"viewDidAppear:",
                                          @"viewWillLayoutSubviews",
                                          @"prefersStatusBarHidden",
                                          @"preferredStatusBarStyle",
                                          @"traitCollectionDidChange:"];
        
        [oriSels enumerateObjectsUsingBlock:^(NSString * _Nonnull oriSel, NSUInteger idx, BOOL * _Nonnull stop) {
            gk_navigationBar_swizzled_instanceMethod(@"gk", self, oriSel, self);
        }];
    });
}

- (void)gk_viewDidLoad {
    // 设置默认导航栏间距
    self.gk_navItemLeftSpace    = GKNavigationBarItemSpace;
    self.gk_navItemRightSpace   = GKNavigationBarItemSpace;
    self.gk_disableFixNavItemSpace = [self checkFixNavItemSpace];
    [self gk_viewDidLoad];
}

- (void)gk_viewWillAppear:(BOOL)animated {
    if ([self isKindOfClass:[UINavigationController class]]) return;
    if ([self isKindOfClass:[UITabBarController class]]) return;
    if ([self isKindOfClass:[UIImagePickerController class]]) return;
    if ([self isKindOfClass:[UIVideoEditorController class]]) return;
    if ([NSStringFromClass(self.class) isEqualToString:@"PUPhotoPickerHostViewController"]) return;
    if (!self.navigationController) return;
    
    if (self.gk_NavBarInit) {
        // 隐藏系统导航栏
        if (!self.navigationController.gk_openSystemNavHandle && !self.navigationController.isNavigationBarHidden) {
            [self.navigationController setNavigationBarHidden:YES];
        }
        
        // 将自定义导航栏放置顶层
        if (self.gk_navigationBar && !self.gk_navigationBar.hidden) {
            [self.view bringSubviewToFront:self.gk_navigationBar];
        }
    }
    
    // 允许调整导航栏间距
    if (!self.gk_disableFixNavItemSpace) {
        // 每次控制器出现的时候重置导航栏间距
        if (self.gk_navItemLeftSpace == GKNavigationBarItemSpace) {
            self.gk_navItemLeftSpace = GKConfigure.navItemLeftSpace;
        }
        
        if (self.gk_navItemRightSpace == GKNavigationBarItemSpace) {
            self.gk_navItemRightSpace = GKConfigure.navItemRightSpace;
        }
    }
    [self gk_viewWillAppear:animated];
}

- (void)gk_viewDidAppear:(BOOL)animated {
    if (self.gk_NavBarInit && !self.navigationController.isNavigationBarHidden) {
        [self.navigationController setNavigationBarHidden:YES];
    }
    [self gk_viewDidAppear:animated];
}

- (void)gk_viewWillLayoutSubviews {
    if (self.gk_NavBarInit) {
        [self setupNavBarFrame];
    }
    [self gk_viewWillLayoutSubviews];
}

- (BOOL)gk_prefersStatusBarHidden {
    return self.gk_statusBarHidden;
}

- (UIStatusBarStyle)gk_preferredStatusBarStyle {
    return self.gk_statusBarStyle;
}

- (void)gk_traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            // 重新设置导航栏颜色
            [self setNavBackgroundColor:self.gk_navBackgroundColor];
            [self setNavShadowColor:self.gk_navShadowColor];
        }
    }
    [self gk_traitCollectionDidChange:previousTraitCollection];
}

#pragma mark - 状态栏
static char kAssociatedObjectKey_statusBarHidden;
- (void)setGk_statusBarHidden:(BOOL)gk_statusBarHidden {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_statusBarHidden, @(gk_statusBarHidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)gk_statusBarHidden {
    id hidden = objc_getAssociatedObject(self, &kAssociatedObjectKey_statusBarHidden);
    return (hidden != nil) ? [hidden boolValue] : GKConfigure.statusBarHidden;
}

static char kAssociatedObjectKey_statusBarStyle;
- (void)setGk_statusBarStyle:(UIStatusBarStyle)gk_statusBarStyle {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_statusBarStyle, @(gk_statusBarStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)gk_statusBarStyle {
    id style = objc_getAssociatedObject(self, &kAssociatedObjectKey_statusBarStyle);
    return (style != nil) ? [style integerValue] : GKConfigure.statusBarStyle;
}

#pragma mark - 添加自定义导航栏
static char kAssociatedObjectKey_navigationBar;
- (GKCustomNavigationBar *)gk_navigationBar {
    GKCustomNavigationBar *navigationBar = objc_getAssociatedObject(self, &kAssociatedObjectKey_navigationBar);
    if (!navigationBar) {
        navigationBar = [[GKCustomNavigationBar alloc] init];
        objc_setAssociatedObject(self, &kAssociatedObjectKey_navigationBar, navigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        self.gk_NavBarInit = YES;
        [self setupNavBarAppearance];
        [self setupNavBarFrame];
    }
    if (self.isViewLoaded && !self.gk_navBarAdded) {
        [self.view addSubview:navigationBar];
        self.gk_navBarAdded = YES;
    }
    return navigationBar;
}

static char kAssociatedObjectKey_navigationItem;
- (UINavigationItem *)gk_navigationItem {
    UINavigationItem *navigationItem = objc_getAssociatedObject(self, &kAssociatedObjectKey_navigationItem);
    if (!navigationItem) {
        navigationItem = [[UINavigationItem alloc] init];
        objc_setAssociatedObject(self, &kAssociatedObjectKey_navigationItem, navigationItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        self.gk_navigationBar.items = @[navigationItem];
    }
    return navigationItem;
}

static char kAssociatedObjectKey_navBarInit;
- (void)setGk_NavBarInit:(BOOL)gk_NavBarInit {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navBarInit, @(gk_NavBarInit), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)gk_NavBarInit {
    return [objc_getAssociatedObject(self, &kAssociatedObjectKey_navBarInit) boolValue];
}

static char kAssociatedObjectKey_navBarAdded;
- (void)setGk_navBarAdded:(BOOL)gk_navBarAdded {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navBarAdded, @(gk_navBarAdded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)gk_navBarAdded {
    return [objc_getAssociatedObject(self, &kAssociatedObjectKey_navBarAdded) boolValue];
}

#pragma mark - 常用属性快速设置
static char kAssociatedObjectKey_navBarAlpha;
- (void)setGk_navBarAlpha:(CGFloat)gk_navBarAlpha {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navBarAlpha, @(gk_navBarAlpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    self.gk_navigationBar.gk_navBarBackgroundAlpha = gk_navBarAlpha;
}

- (CGFloat)gk_navBarAlpha {
    id obj = objc_getAssociatedObject(self, &kAssociatedObjectKey_navBarAlpha);
    return obj ? [obj floatValue] : 1.0f;
}

static char kAssociatedObjectKey_backImage;
- (void)setGk_backImage:(UIImage *)gk_backImage {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_backImage, gk_backImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setBackItemImage:gk_backImage];
}

- (UIImage *)gk_backImage {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_backImage);
}

static char kAssociatedObjectKey_backStyle;
- (void)setGk_backStyle:(GKNavigationBarBackStyle)gk_backStyle {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_backStyle, @(gk_backStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setBackItemImage:self.gk_backImage];
}

- (GKNavigationBarBackStyle)gk_backStyle {
    id style = objc_getAssociatedObject(self, &kAssociatedObjectKey_backStyle);
    return (style != nil) ? [style integerValue] : GKNavigationBarBackStyleNone;
}

static char kAssociatedObjectKey_navBackgroundColor;
- (void)setGk_navBackgroundColor:(UIColor *)gk_navBackgroundColor {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navBackgroundColor, gk_navBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setNavBackgroundColor:gk_navBackgroundColor];
}

- (UIColor *)gk_navBackgroundColor {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navBackgroundColor);
}

static char kAssociatedObjectKey_navBackgroundImage;
- (void)setGk_navBackgroundImage:(UIImage *)gk_navBackgroundImage {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navBackgroundImage, gk_navBackgroundImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.gk_navigationBar setBackgroundImage:gk_navBackgroundImage forBarMetrics:UIBarMetricsDefault];
}

- (UIImage *)gk_navBackgroundImage {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navBackgroundImage);
}

static char kAssociatedObjectKey_navShadowColor;
- (void)setGk_navShadowColor:(UIColor *)gk_navShadowColor {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navShadowColor, gk_navShadowColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setNavShadowColor:gk_navShadowColor];
}

- (UIColor *)gk_navShadowColor {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navShadowColor);
}

static char kAssociatedObjectKey_navShadowImage;
- (void)setGk_navShadowImage:(UIImage *)gk_navShadowImage {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navShadowImage, gk_navShadowImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationBar.shadowImage = gk_navShadowImage;
}

- (UIImage *)gk_navShadowImage {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navShadowImage);
}

static char kAssociatedObjectKey_navLineHidden;
- (void)setGk_navLineHidden:(BOOL)gk_navLineHidden {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navLineHidden, @(gk_navLineHidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationBar.gk_navLineHidden = gk_navLineHidden;
    
    if (@available(iOS 11.0, *)) {
        UIImage *shadowImage = nil;
        if (gk_navLineHidden) {
            shadowImage = [UIImage new];
        }else if (self.gk_navShadowImage) {
            shadowImage = self.gk_navShadowImage;
        }else if (self.gk_navShadowColor) {
            shadowImage = [UIImage gk_changeImage:[UIImage gk_imageNamed:@"nav_line"] color:self.gk_navShadowColor];
        }
        
        self.gk_navigationBar.shadowImage = shadowImage;
    }
    [self.gk_navigationBar layoutSubviews];
}

- (BOOL)gk_navLineHidden {
    return [objc_getAssociatedObject(self, &kAssociatedObjectKey_navLineHidden) boolValue];
}

static char kAssociatedObjectKey_navTitle;
- (void)setGk_navTitle:(NSString *)gk_navTitle {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navTitle, gk_navTitle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationItem.title = gk_navTitle;
}

- (NSString *)gk_navTitle {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navTitle);
}

static char kAssociatedObjectKey_navTitleView;
- (void)setGk_navTitleView:(UIView *)gk_navTitleView {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navTitleView, gk_navTitleView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationItem.titleView = gk_navTitleView;
}

- (UIView *)gk_navTitleView {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navTitleView);
}

static char kAssociatedObjectKey_navTitleColor;
- (void)setGk_navTitleColor:(UIColor *)gk_navTitleColor {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navTitleColor, gk_navTitleColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setNavTitleColor:gk_navTitleColor];
}

- (UIColor *)gk_navTitleColor {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navTitleColor);
}

static char kAssociatedObjectKey_navTitleFont;
- (void)setGk_navTitleFont:(UIFont *)gk_navTitleFont {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navTitleFont, gk_navTitleFont, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setNavTitleFont:self.gk_navTitleFont];
}

- (UIFont *)gk_navTitleFont {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navTitleFont);
}

static char kAssociatedObjectKey_navLeftBarButtonItem;
- (void)setGk_navLeftBarButtonItem:(UIBarButtonItem *)gk_navLeftBarButtonItem {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navLeftBarButtonItem, gk_navLeftBarButtonItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationItem.leftBarButtonItem = gk_navLeftBarButtonItem;
}

- (UIBarButtonItem *)gk_navLeftBarButtonItem {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navLeftBarButtonItem);
}

static char kAssociatedObjectKey_navLeftBarButtonItems;
- (void)setGk_navLeftBarButtonItems:(NSArray<UIBarButtonItem *> *)gk_navLeftBarButtonItems {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navLeftBarButtonItems, gk_navLeftBarButtonItems, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationItem.leftBarButtonItems = gk_navLeftBarButtonItems;
}

- (NSArray<UIBarButtonItem *> *)gk_navLeftBarButtonItems {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navLeftBarButtonItems);
}

static char kAssociatedObjectKey_navRightBarButtonItem;
- (void)setGk_navRightBarButtonItem:(UIBarButtonItem *)gk_navRightBarButtonItem {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navRightBarButtonItem, gk_navRightBarButtonItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationItem.rightBarButtonItem = gk_navRightBarButtonItem;
}

- (UIBarButtonItem *)gk_navRightBarButtonItem {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navRightBarButtonItem);
}

static char kAssociatedObjectKey_navRightBarButtonItems;
- (void)setGk_navRightBarButtonItems:(NSArray<UIBarButtonItem *> *)gk_navRightBarButtonItems {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navRightBarButtonItems, gk_navRightBarButtonItems, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.gk_navigationItem.rightBarButtonItems = gk_navRightBarButtonItems;
}

- (NSArray<UIBarButtonItem *> *)gk_navRightBarButtonItems {
    return objc_getAssociatedObject(self, &kAssociatedObjectKey_navRightBarButtonItems);
}

static char kAssociatedObjectKey_disableFixNavItemSpace;
- (void)setGk_disableFixNavItemSpace:(BOOL)gk_disableFixNavItemSpace {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_disableFixNavItemSpace, @(gk_disableFixNavItemSpace), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (gk_disableFixNavItemSpace != GKConfigure.gk_disableFixSpace) {
        [GKConfigure updateConfigure:^(GKNavigationBarConfigure * _Nonnull configure) {
            configure.gk_disableFixSpace = gk_disableFixNavItemSpace;
        }];
    }
}

- (BOOL)gk_disableFixNavItemSpace {
    return [objc_getAssociatedObject(self, &kAssociatedObjectKey_disableFixNavItemSpace) boolValue];
}

static char kAssociatedObjectKey_navItemLeftSpace;
- (void)setGk_navItemLeftSpace:(CGFloat)gk_navItemLeftSpace {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navItemLeftSpace, @(gk_navItemLeftSpace), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (gk_navItemLeftSpace == GKNavigationBarItemSpace) return;
    
    [GKConfigure updateConfigure:^(GKNavigationBarConfigure * _Nonnull configure) {
        configure.gk_navItemLeftSpace = gk_navItemLeftSpace;
    }];
}

- (CGFloat)gk_navItemLeftSpace {
    return [objc_getAssociatedObject(self, &kAssociatedObjectKey_navItemLeftSpace) floatValue];
}

static char kAssociatedObjectKey_navItemRightSpace;
- (void)setGk_navItemRightSpace:(CGFloat)gk_navItemRightSpace {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navItemRightSpace, @(gk_navItemRightSpace), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (gk_navItemRightSpace == GKNavigationBarItemSpace) return;
    
    [GKConfigure updateConfigure:^(GKNavigationBarConfigure * _Nonnull configure) {
        configure.gk_navItemRightSpace = gk_navItemRightSpace;
    }];
}

- (CGFloat)gk_navItemRightSpace {
    return [objc_getAssociatedObject(self, &kAssociatedObjectKey_navItemRightSpace) floatValue];
}

#pragma mark - Public Methods
- (void)showNavLine {
    self.gk_navLineHidden = NO;
}

- (void)hideNavLine {
    self.gk_navLineHidden = YES;
}

- (void)refreshNavBarFrame {
    [self setupNavBarFrame];
}

- (void)backItemClick:(id)sender {
#if HasGestureHandle
    BOOL shouldPop = [self navigationShouldPop];
    if ([self respondsToSelector:@selector(navigationShouldPopOnClick)]) {
        shouldPop = [self navigationShouldPopOnClick];
    }
    if (shouldPop) {
        [self.navigationController popViewControllerAnimated:YES];
    }
#else
    [self.navigationController popViewControllerAnimated:YES];
#endif
}

- (UIViewController *)gk_visibleViewControllerIfExist {
    if (self.presentedViewController) {
        return [self.presentedViewController gk_visibleViewControllerIfExist];
    }
    if ([self isKindOfClass:[UINavigationController class]]) {
        return [((UINavigationController *)self).topViewController gk_visibleViewControllerIfExist];
    }
    if ([self isKindOfClass:[UITabBarController class]]) {
        return [((UITabBarController *)self).selectedViewController gk_visibleViewControllerIfExist];
    }
    if ([self isViewLoaded] && self.view.window) {
        return self;
    }else {
        NSLog(@"找不到可见的控制器，viewcontroller.self = %@，self.view.window=%@", self, self.view.window);
        return nil;
    }
}

#pragma mark - Private Methods
- (void)setupNavBarAppearance {
    // 设置默认背景色
    if (self.gk_navBackgroundColor == nil) {
        self.gk_navBackgroundColor = GKConfigure.backgroundColor;
    }
    
    // 设置分割线颜色
    if (self.gk_navShadowColor == nil && GKConfigure.lineColor) {
        self.gk_navShadowColor = GKConfigure.lineColor;
    }
    
    // 设置分割线是否隐藏
    if (self.gk_navLineHidden == NO && GKConfigure.lineHidden == YES) {
        self.gk_navLineHidden = GKConfigure.lineHidden;
    }
    
    // 设置默认标题字体
    if (self.gk_navTitleFont == nil) {
        self.gk_navTitleFont = GKConfigure.titleFont;
    }
    
    // 设置默认标题颜色
    if (self.gk_navTitleColor == nil) {
        self.gk_navTitleColor = GKConfigure.titleColor;
    }
    
    // 设置默认返回图片
    if (self.gk_backImage == nil) {
        self.gk_backImage = GKConfigure.backImage;
    }
    
    // 设置默认返回样式
    if (self.gk_backStyle == GKNavigationBarBackStyleNone) {
        self.gk_backStyle = GKConfigure.backStyle;
    }
}

- (void)setupNavBarFrame {
    CGFloat navBarH = 0.0f;
    if (GK_IS_iPad) { // iPad
        navBarH = self.gk_statusBarHidden ? GK_NAVBAR_HEIGHT : GK_STATUSBAR_NAVBAR_HEIGHT;
    }else if (GK_IS_LANDSCAPE) { // 横屏不显示状态栏
        navBarH = GK_NAVBAR_HEIGHT;
    }else {
        if (GK_NOTCHED_SCREEN) { // 刘海屏手机
            navBarH = GK_SAFEAREA_TOP + GK_NAVBAR_HEIGHT;
        }else {
            navBarH = self.gk_statusBarHidden ? GK_NAVBAR_HEIGHT : GK_STATUSBAR_NAVBAR_HEIGHT;
        }
    }
    self.gk_navigationBar.frame = CGRectMake(0, 0, GK_SCREEN_WIDTH, navBarH);
    [self.gk_navigationBar layoutSubviews];
}

- (BOOL)checkFixNavItemSpace {
    // 判断是否需要屏蔽导航栏间距调整
    __block BOOL exist = NO;
    [GKConfigure.shiledItemSpaceVCs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([[obj class] isSubclassOfClass:[UIViewController class]]) {
            if ([self isKindOfClass:[obj class]]) {
                exist = YES;
                *stop = YES;
            }
        }else if ([obj isKindOfClass:[NSString class]]) {
            if ([NSStringFromClass(self.class) isEqualToString:obj]) {
                exist = YES;
                *stop = YES;
            }else if ([NSStringFromClass(self.class) containsString:obj]) {
                exist = YES;
                *stop = YES;
            }
        }
    }];
    return exist;
}

- (void)setBackItemImage:(UIImage *)image {
    if (!self.gk_NavBarInit) return;
    // 根控制器不作处理
    if (self.navigationController.childViewControllers.count <= 1) return;
    
    if (!image) {
        if (self.gk_backStyle != GKNavigationBarBackStyleNone) {
            NSString *imageName = self.gk_backStyle == GKNavigationBarBackStyleBlack ? @"btn_back_black" : @"btn_back_white";
            image = [UIImage gk_imageNamed:imageName];
        }
    }
    
    // 没有image
    if (!image) return;
    
    self.gk_navLeftBarButtonItem = [UIBarButtonItem gk_itemWithImage:image target:self action:@selector(backItemClick:)];
}

- (void)setNavBackgroundColor:(UIColor *)color {
    if (!color) return;
    [self.gk_navigationBar setBackgroundImage:[UIImage gk_imageWithColor:color] forBarMetrics:UIBarMetricsDefault];
}

- (void)setNavShadowColor:(UIColor *)color {
    if (!color) return;
    self.gk_navigationBar.shadowImage = [UIImage gk_changeImage:[UIImage gk_imageNamed:@"nav_line"] color:color];
}

- (void)setNavTitleColor:(UIColor *)color {
    if (!color) return;
    
    NSMutableDictionary *attr = [NSMutableDictionary dictionary];
    attr[NSForegroundColorAttributeName] = color;
    if (self.gk_navTitleFont) {
        attr[NSFontAttributeName] = self.gk_navTitleFont;
    }
    
    self.gk_navigationBar.titleTextAttributes = attr;
}

- (void)setNavTitleFont:(UIFont *)font {
    if (!font) return;
    
    NSMutableDictionary *attr = [NSMutableDictionary dictionary];
    if (self.gk_navTitleColor) {
        attr[NSForegroundColorAttributeName] = self.gk_navTitleColor;
    }
    attr[NSFontAttributeName] = font;
    self.gk_navigationBar.titleTextAttributes = attr;
}

@end
