//
//  main.m
//  Gabtastik
//
//  Created by Danny Espinoza on 4/28/08.
//  Copyright Mesa Dynamics, LLC 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

SInt32 gMacVersion = 0;

int main(int argc, char *argv[])
{
	Gestalt(gestaltSystemVersion, &gMacVersion);
    return NSApplicationMain(argc,  (const char **) argv);
}
