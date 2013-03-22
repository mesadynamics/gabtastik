//
//  Transformers.m
//  Gabtastik
//
//  Created by Danny Espinoza on 4/28/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "Transformers.h"


@implementation ValueIsNotOneTransformer
+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
    if([value intValue] == 100.0)
		return [NSNumber numberWithBool:NO];
	
	return [NSNumber numberWithBool:YES];
}
@end
