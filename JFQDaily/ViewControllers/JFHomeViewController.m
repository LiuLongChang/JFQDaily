//
//  JFHomeViewController.m
//  JFQDaily
//
//  Created by 张志峰 on 2016/11/4.
//  Copyright © 2016年 zhifenx. All rights reserved.
//  代码地址：https://github.com/zhifenx/JFQDaily
//  简书地址：http://www.jianshu.com/users/aef0f8eebe6d/latest_articles

#import "JFHomeViewController.h"

//工具类
#import "JFConfigFile.h"
#import "JFLoopView.h"
#import "YYFPSLabel.h"

//第三方开源框架
#import <Masonry.h>
#import <MJRefresh.h>
#import "MJExtension.h"

//
#import "MBProgressHUD+JFProgressHUD.h"
#import "JFSuspensionView.h"
#import "JFHomeNewsDataManager.h"
#import "JFHomeNewsTableViewCell.h"
#import "JFReaderViewController.h"
#import "JFMenuView.h"

//新闻数据模型相关
#import "JFResponseModel.h"
#import "JFNewsCellLayout.h"
#import "JFQDaily-Swift.h"

@interface JFHomeViewController ()<UITableViewDelegate, UITableViewDataSource, JFMenuViewDelegate, JFSuspensionViewDelegate>
{
    NSString *_last_key;        // 上拉加载请求数据时需要拼接到URL中的last_key
    NSString *_has_more;        // 是否还有未加载的文章（0：没有 1：有）
    CGFloat _contentOffset_Y;   // homeNewsTableView滑动后Y轴偏移量
    NSInteger _row;
    BOOL _isRuning;             // 定时器是否在运行
    BOOL _isBeyondBorder;        // 轮播view是否超出显示区域
}

@property (nonatomic, strong) UITableView *homeNewsTableView;
@property (nonatomic, strong) MJRefreshNormalHeader *refreshHeader;
@property (nonatomic, strong) MJRefreshAutoNormalFooter *refreshFooter;
@property (nonatomic, strong) JFHomeNewsTableViewCell *cell;
@property (nonatomic, strong) JFMenuView *menuView;
@property (nonatomic, strong) JFLoopView *loopView;
@property (nonatomic, strong) YYFPSLabel *fpsLabel;
/** 悬浮按钮view*/
@property (nonatomic, strong) JFSuspensionView *jfSuspensionView;
@property (nonatomic, strong) JFHomeNewsDataManager *manager;
@property (nonatomic, strong) JFResponseModel *response;
@property (nonatomic, strong) NSArray *feedsArray;
@property (nonatomic, strong) NSArray *bannersArray;
@property (nonatomic, strong) NSArray *imageArray;
/** 主要内容数组*/
@property (nonatomic, strong) NSMutableArray *contentMutableArray;
@property (nonatomic, strong) NSMutableArray <JFNewsCellLayout *> *layouts;

@end

@implementation JFHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    
    [self.view addSubview:self.homeNewsTableView];
    [self.view addSubview:self.jfSuspensionView];
    
    self.contentMutableArray = [[NSMutableArray alloc] init];
    self.layouts = [[NSMutableArray alloc] init];
    self.imageArray = [[NSArray alloc] init];
    
    //请求数据
    [self.manager requestHomeNewsDataWithLastKey:@"0"];
    
    //设置下拉刷新
    self.refreshHeader = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        [self refreshData];
    }];
    self.refreshHeader.lastUpdatedTimeLabel.hidden = YES;
    self.refreshHeader.stateLabel.hidden = YES;
    self.homeNewsTableView.mj_header = self.refreshHeader;
    
    //设置上拉加载
    self.refreshFooter = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{
        [self loadData]; //已在scrollViewDidScroll里提供了加载数据
    }];
    [self.refreshFooter setTitle:@"加载更多 ..." forState:MJRefreshStateRefreshing];
    [self.refreshFooter setTitle:@"没有更多内容了" forState:MJRefreshStateNoMoreData];
    self.homeNewsTableView.mj_footer = self.refreshFooter;
    
    //FPS Label
    _fpsLabel = [[YYFPSLabel alloc] initWithFrame:CGRectMake(20, 44, 100, 30)];
    [_fpsLabel sizeToFit];
    [self.view addSubview:_fpsLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.automaticallyAdjustsScrollViewInsets = NO;
    if (!_isBeyondBorder) {
        [self.loopView startTimer];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (_isRuning && !_isBeyondBorder) {
        [self.loopView stopTimer];
        _isRuning = NO;
    }
}

/// 下拉刷新数据
- (void)refreshData {
    //下拉刷新时清空数据
    [_layouts removeAllObjects];
    [self.manager requestHomeNewsDataWithLastKey:@"0"];
}

/// 上拉加载数据
- (void)loadData {
    //判断是否还有更多数据
    if ([_has_more isEqualToString:@"1"]) {
        [self.manager requestHomeNewsDataWithLastKey:_last_key];
    }else if ([_has_more isEqualToString:@"0"]) {
        [self.refreshFooter setState:MJRefreshStateNoMoreData];
    }
}

/// 悬浮按钮view
- (JFSuspensionView *)jfSuspensionView {
    if (!_jfSuspensionView) {
        _jfSuspensionView = [[JFSuspensionView alloc] initWithFrame:CGRectMake(10, JFSCREENH_HEIGHT - 70, 54, 54)];
        _jfSuspensionView.delegate = self;
        //设置按钮样式（tag）
        _jfSuspensionView.JFSuspensionButtonStyle = JFSuspensionButtonStyleQType;
    }
    return _jfSuspensionView;
}

/// 改变悬浮按钮的X值
- (void)suspensionViewOffsetX:(CGFloat)offsetX {
    CGRect tempFrame = self.jfSuspensionView.frame;
    tempFrame.origin.x = offsetX;
    self.jfSuspensionView.frame = tempFrame;
}

#pragma mark --- 菜单
- (JFMenuView *)menuView {
    if (!_menuView) {
        _menuView = [[JFMenuView alloc] initWithFrame:self.view.bounds];
        _menuView.backgroundColor = [UIColor clearColor];
        _menuView.delegate = self;
    }
    return _menuView;
}

#pragma mark --- 数据管理器
- (JFHomeNewsDataManager *)manager {
    if (!_manager) {
        _manager = [[JFHomeNewsDataManager alloc] init];
        __weak typeof(self) weakSelf = self;
        [_manager newsDataBlock:^(id data) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                
                strongSelf.response = [JFResponseModel mj_objectWithKeyValues:data];
                _last_key = strongSelf.response.last_key;
                _has_more = strongSelf.response.has_more;
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    //使用MJExtension讲josn数据转成数组
                    strongSelf.bannersArray = [JFFeedsModel mj_objectArrayWithKeyValuesArray:[data valueForKey:@"banners"]];
                    //使用MJExtension讲josn数据转成数组
                    strongSelf.feedsArray = [JFFeedsModel mj_objectArrayWithKeyValuesArray:[data valueForKey:@"feeds"]];
                    for (JFFeedsModel *feed in strongSelf.feedsArray) {
                        JFNewsCellLayout *layout = [[JFNewsCellLayout alloc] initWithModel:feed style:[feed.type integerValue]];
                        [strongSelf.layouts addObject:layout];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        //停止刷新
                        [strongSelf.refreshHeader endRefreshing];
                        [strongSelf.refreshFooter endRefreshing];
                        [strongSelf startLoopView];
                        [strongSelf.homeNewsTableView reloadData];
                    });
                });
            }
        }];
    }
    return _manager;
}

#pragma mark --- 图片轮播器
- (void)startLoopView {
    //如果是上拉加载数据，就不再次加载轮播图
    if (_loopView.newsUrlMutableArray.count == 0) {
        _isRuning = YES;
        NSMutableArray *imageMuatableArray = [[NSMutableArray alloc] init];
        NSMutableArray *titleMutableArray = [[NSMutableArray alloc] init];
        NSMutableArray *newsUrlMuatbleArray = [[NSMutableArray alloc] init];
        for (JFBannersModel *banner in self.bannersArray) {
            [imageMuatableArray addObject:banner.post.image];
            [titleMutableArray addObject:banner.post.title];
            [newsUrlMuatbleArray addObject:banner.post.appview];
        }
        [_loopView loopViewDataWithImageMutableArray:imageMuatableArray titleMutableArray:titleMutableArray];
        _loopView.newsUrlMutableArray = newsUrlMuatbleArray;
        
        __weak typeof(self) weakSelf = self;
        [_loopView didSelectCollectionItemBlock:^(NSString *Url) {
            [weakSelf pushToJFReaderViewControllerWithNewsUrl:Url];
        }];
    }
}

#pragma mark --- JFHomeNewsTableView（首页根view）
- (UITableView *)homeNewsTableView {
    if (!_homeNewsTableView) {
        _homeNewsTableView = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStylePlain];
        _homeNewsTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _homeNewsTableView.delegate = self;
        _homeNewsTableView.dataSource = self;
        _homeNewsTableView.tableHeaderView = self.loopView;
    }
    return _homeNewsTableView;
}

- (JFLoopView *)loopView {
    if (!_loopView) {
        _loopView = [[JFLoopView alloc] initWithFrame:CGRectMake(0, 0, JFSCREEN_WIDTH, 300)];
    }
    return _loopView;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _layouts.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return ((JFNewsCellLayout *)_layouts[indexPath.row]).height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellID = @"newsCell";
    self.cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!_cell) {
        _cell = [[JFHomeNewsTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    [_cell setLayout:_layouts[indexPath.row]];
    return _cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    JFNewsCellLayout *layout = _layouts[indexPath.row];
    if (![layout.model.type isEqualToString:@"0"]) {
        [self pushToJFReaderViewControllerWithNewsUrl:layout.model.post.appview];
    }else {
        [MBProgressHUD promptHudWithShowHUDAddedTo:self.view message:@"抱歉，未抓取到相关链接！"];
    }
}

/// push到JFReaderViewController
- (void)pushToJFReaderViewControllerWithNewsUrl:(NSString *)newsUrl {
    JFReaderViewController *readerVC = [[JFReaderViewController alloc] init];
    readerVC.newsUrl = newsUrl;
    [self.navigationController pushViewController:readerVC animated:YES];
}

#pragma mark --- UIScrollDelegate
/// 滚动时调用
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y > _contentOffset_Y + 80) {
        [self suspensionWithAlpha:0];
    } else if (scrollView.contentOffset.y < _contentOffset_Y) {
        [self suspensionWithAlpha:1];
    }
    
    if (scrollView.contentOffset.y > 400) {         // 轮播图滑出界面时，关闭定时器
        if (_isRuning) {
            [self.loopView stopTimer];
            _isBeyondBorder = YES;
            _isRuning = NO;
        }
    }else if (scrollView.contentOffset.y < 400) {   // 轮播图进入界面时，打开定时器
        if (!_isRuning) {
            [self.loopView startTimer];
            _isRuning = YES;
            _isBeyondBorder = NO;
        }
    }
    
    //提前加载数据，以提供更流畅的用户体验
    NSIndexPath *indexPatch = [_homeNewsTableView indexPathForRowAtPoint:CGPointMake(40, scrollView.contentOffset.y)];
    if (indexPatch.row == (_layouts.count - 10)) {
        if (_row == indexPatch.row) return;//避免重复加载
        _row = indexPatch.row;
        [self loadData];
    }
}

/// 停止滚动时调用
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    _contentOffset_Y = scrollView.contentOffset.y;
    //停止后显示悬浮按钮
    [self suspensionWithAlpha:1];
}

/// 设置悬浮按钮view透明度，以此显示和隐藏悬浮按钮
- (void)suspensionWithAlpha:(CGFloat)alpha {
    [UIView animateWithDuration:0.3
                     animations:^{
                         [self.jfSuspensionView setAlpha:alpha];
                     }];
}

#pragma mark - JFMenuViewDelegate
- (void)clickTheSettingButtonEvent {
    RegisterController *registerVC = [[RegisterController alloc] init];
    [self presentViewController:registerVC animated:YES completion:nil];
}

- (void)popupNewsClassificationView {
    //重置悬浮按钮的Tag
    self.jfSuspensionView.JFSuspensionButtonStyle = JFSuspensionButtonStyleBackType2;
    [self suspensionViewOffsetX:-JFSCREEN_WIDTH - 100];
}

- (void)hideNewsClassificationView {
    //隐藏新闻分类菜单
    [self.menuView hideJFNewsClassificationViewAnimation];
    //弹簧效果动画
    [UIView animateWithDuration:0.7 //动画时间
                          delay:0   //动画延迟
         usingSpringWithDamping:0.5 //越接近零，震荡越大；1时为平滑的减速动画
          initialSpringVelocity:0.15 //弹簧的初始速度 （距离/该值）pt/s
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [self suspensionViewOffsetX:10];
                     }
                     completion:nil];
}

#pragma mark - JFSuspensionViewDelegate

- (void)popupMenuView {
    [self.view insertSubview:self.menuView
                      belowSubview:self.jfSuspensionView];
    [self.menuView popupMenuViewAnimation];
}

- (void)closeMenuView {
    [_menuView hideMenuViewAnimation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
