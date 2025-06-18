//
//  EPRecorderOptions.h
//  EPSpy
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>

@interface EPRecorderOptions: NSObject <NSSecureCoding>

@property BOOL ignorePlatformProcesses;
@property BOOL expandProcess;
@property BOOL recordLaunchArguments;
@property BOOL recordEnvironmentVariables;

@end
