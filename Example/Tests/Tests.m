//
//  TTGDeallocTaskHelperTests.m
//  TTGDeallocTaskHelperTests
//
//  Created by zekunyan on 07/17/2016.
//  Copyright (c) 2016 zekunyan. All rights reserved.
//

@import XCTest;

#import <TTGDeallocTaskHelper/NSObject+TTGDeallocTaskHelper.h>
#import <pthread.h>

@interface TestObject : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSUInteger num;
@end

@implementation TestObject

- (void)func1 {
    NSLog(@"TestObject func1: %ld, %@", _num, _name);
}

@end

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSingleDeallocTask {
    __block BOOL flag = NO;
    __block NSUInteger num = 0;
    __block NSString *name = nil;
    
    {
        TestObject *test1 = [TestObject new];
        test1.num = 1;
        test1.name = [NSString stringWithFormat:@"name: %ld", test1.num];
        
        [test1 ttg_addDeallocTask:^(__unsafe_unretained TestObject *object, NSUInteger identifier) {
            NSLog(@"test object dealloc task: %@, identifier: %ld", object, identifier);
            [object func1];
            flag = YES;
            num = object.num;
            name = object.name;
        }];
        
    }
    
    XCTAssert(flag);
    XCTAssert(num == 1);
    XCTAssert(name == nil);
}

- (void)testRemoveAllTask {
    NSMutableIndexSet *identifierSet = [NSMutableIndexSet new];
    dispatch_group_t group = dispatch_group_create();
    NSUInteger taskCount = 100;
    
    __block NSUInteger num = 0;
    __block pthread_mutex_t lock;
    pthread_mutex_init(&lock, NULL);

    TestObject *testObject = [TestObject new];
    
    for (NSUInteger i = 0; i < taskCount; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            // Test multi thread add tasks
            NSUInteger newIdentifier = [testObject ttg_addDeallocTask:^(__unsafe_unretained TestObject *object, NSUInteger identifier) {
                pthread_mutex_lock(&lock);
                num += 1;
                pthread_mutex_unlock(&lock);
            }];
            
            pthread_mutex_lock(&lock);
            [identifierSet addIndex:newIdentifier];
            pthread_mutex_unlock(&lock);
           
            dispatch_group_leave(group);
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Remove all dealloc tasks
    [testObject ttg_removeAllDeallocTasks];
    testObject = nil;
    
    NSLog(@"num: %ld, identifiers: %ld, %@", num, identifierSet.count, identifierSet);
    XCTAssert(num == 0);
    XCTAssert(identifierSet.count == taskCount);
}

- (void)testMultiThreadDeallocTask {
    NSMutableIndexSet *identifierSet = [NSMutableIndexSet new];
    dispatch_group_t group = dispatch_group_create();
    NSUInteger objectCount = 1000;
    NSUInteger taskCount = 1000;
    
    __block NSUInteger num = 0;
    __block pthread_mutex_t lock;
    pthread_mutex_init(&lock, NULL);
    
    {
        for (NSUInteger j = 0; j < objectCount; j++) {
            TestObject *testObject = [TestObject new];
            
            for (NSUInteger i = 0; i < taskCount; i++) {
                dispatch_group_enter(group);
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    
                    // Test multi thread add tasks
                    NSUInteger newIdentifier = [testObject ttg_addDeallocTask:^(__unsafe_unretained TestObject *object, NSUInteger identifier) {
                        pthread_mutex_lock(&lock);
                        num += 1;
                        pthread_mutex_unlock(&lock);
                        dispatch_group_leave(group);
                    }];
                    
                    pthread_mutex_lock(&lock);
                    [identifierSet addIndex:newIdentifier];
                    pthread_mutex_unlock(&lock);
                    
                    if (i == 0) {
                        // Test multi thread remove tasks
                        [testObject ttg_removeDeallocTaskByIdentifier:newIdentifier];
                        dispatch_group_leave(group);
                    }
                });
            }
        }
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    NSLog(@"num: %ld, identifiers: %ld", num, identifierSet.count);
    XCTAssert(num == objectCount * taskCount - objectCount);
    XCTAssert(identifierSet.count == objectCount * taskCount);
}

@end

