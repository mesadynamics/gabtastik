//
//  ActionText.m
//	Gabtasktik
//
//  Created by Danny Espinoza on 1/4/08.
//  Copyright 2007 Mesa Dynamics, LLC. All rights reserved.
//

#import "ActionText.h"


@implementation ActionText

- (void)mouseDown:(NSEvent *)theEvent
{
	if([theEvent clickCount] == 2) {
		[self performClick:self];
	}
}

@end
