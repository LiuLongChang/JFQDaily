//
//  JFLoopView.m
//  MaYi
//
//  Created by 张志峰 on 2016/10/29.
//  Copyright © 2016年 zhifenx. All rights reserved.
//  代码地址：https://github.com/zhifenx/JFQDaily
//  简书地址：http://www.jianshu.com/users/aef0f8eebe6d/latest_articles

#import "JFLoopView.h"

#import "JFLoopViewLayout.h"
#import "JFLoopViewCell.h"
#import "NSTimer+JFBlocksTimer.h"
#import "JFReaderViewController.h"

@interface JFLoopView () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) NSMutableArray *imageMutableArray;
@property (nonatomic, strong) NSMutableArray *titleMutableArray;
@property (nonatomic, strong) NSTimer *timer;

@end

static NSString *ID = @"loopViewCell";

@implementation JFLoopView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.imageMutableArray = [NSMutableArray new];
        self.titleMutableArray = [NSMutableArray new];
        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[[JFLoopViewLayout alloc] init]];
        [collectionView registerClass:[JFLoopViewCell class] forCellWithReuseIdentifier:ID];
        collectionView.dataSource = self;
        collectionView.delegate = self;
        [self addSubview:collectionView];
        self.collectionView = collectionView;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.collectionView.frame = self.bounds;
}

- (void)loopViewDataWithImageMutableArray:(NSMutableArray *)imageMutableArray
                        titleMutableArray:(NSMutableArray *)titleMutableArray {
    self.imageMutableArray = imageMutableArray;
    self.titleMutableArray = titleMutableArray;
    //添加分页器
    [self addSubview:self.pageControl];
    //回到主线程刷新UI
    dispatch_async(dispatch_get_main_queue(), ^{
//        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:self.imageMutableArray.count inSection:0] atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
    [self.collectionView reloadData];
        //添加定时器
        [self addTimer];
    });
}

/// 懒加载pageControl
- (UIPageControl *)pageControl {
    if (!_pageControl) {
        _pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 270, self.frame.size.width, 30)];
        _pageControl.numberOfPages = self.imageMutableArray.count;
        _pageControl.pageIndicatorTintColor = [UIColor grayColor];
        _pageControl.currentPageIndicatorTintColor = [UIColor orangeColor];
    }
    return _pageControl;
}


/// 重写newsUrl属性的set方法
- (void)setNewsUrlMutableArray:(NSMutableArray *)newsUrlMutableArray {
    _newsUrlMutableArray = newsUrlMutableArray;
}

#pragma mark UICollectionViewDataSource 数据源方法
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageMutableArray.count * 3;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    JFLoopViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:ID forIndexPath:indexPath];
    cell.imageName = self.imageMutableArray[indexPath.item % self.imageMutableArray.count];
    cell.title = self.titleMutableArray[indexPath.item % self.titleMutableArray.count];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.didSelectCollectionItemBlock) {
        self.didSelectCollectionItemBlock(_newsUrlMutableArray[indexPath.row % _newsUrlMutableArray.count]);
    }
}

- (void)didSelectCollectionItemBlock:(JFLoopViewBlock)block {
    self.didSelectCollectionItemBlock = block;
}

#pragma mark ---- UICollectionViewDelegate

/// 开始拖地时调用
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self scrollViewDidEndDecelerating:scrollView];
}

/// 当滚动减速时调用
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat offsetX = scrollView.contentOffset.x;
    NSInteger page = offsetX / scrollView.bounds.size.width;
    if (page == 0) {
        page = self.imageMutableArray.count;
        self.collectionView.contentOffset = CGPointMake(page * scrollView.frame.size.width, 0);
    }else if (page == [self.collectionView numberOfItemsInSection:0] - 1) {
        page = self.imageMutableArray.count - 1;
        self.collectionView.contentOffset = CGPointMake(page * scrollView.frame.size.width, 0);
    }
    
    //设置UIPageControl当前页
    NSInteger currentPage = page % self.imageMutableArray.count;
    self.pageControl.currentPage =currentPage;
    //添加定时器
    [self addTimer];
}


- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    //移除定时器
    [self removeTimer];
}

/// 添加定时器
- (void)addTimer {
    if (self.timer) return;
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer jf_scheduledTimerWithTimeInterval:4 block:^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf nextImage];
        }
    }
                                                    repeats:YES];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [[touches anyObject] locationInView:<#(nullable UIView *)#>];
}

/// 移除定时器
- (void)removeTimer {
    [self.timer invalidate];
    self.timer = nil;
}

/// 切换到下一张图片
- (void)nextImage {
    CGFloat offsetX = self.collectionView.contentOffset.x;
    NSInteger page = offsetX / self.collectionView.bounds.size.width;
    [self.collectionView setContentOffset:CGPointMake((page + 1) * self.collectionView.bounds.size.width, 0) animated:YES];
}

- (void)startTimer {
    [self.timer setFireDate:[NSDate distantPast]];
}

- (void)stopTimer {
    [self.timer setFireDate:[NSDate distantFuture]];
}

- (void)dealloc {
    [self removeTimer];
}

@end
