//
//  SSHAskPass.m
//
//  Created by Ira Cooke on 27/07/2009. Modified with permission by Chetan Surpur on 11/19/10.
//  Copyright 2009 Mudflat Software. 
//

#include <Cocoa/Cocoa.h>
#import "PasswordController.h"

/*! The ASKPASS program for ssh (and for rsync via ssh). 
 
 When ssh (or rsync) needs a response from the user it asks this program instead (provided that ssh or rsync have been started with the appropriate environment variables set).
 
 Sometimes ssh will ask for a password, but if a connection is being established to a server for the first time it will ask whether the user wants to add the host to the list of known hosts (in that case the required response is "yes"). This program figures out what the correct response is and supplies it. 
 
 If a password for the user/hostname combination is not available this program will prompt the user for a password.
 
 */

int main() {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	// Get basic information from environment variables that were set along with the NSTask itself
	NSDictionary *dict = [[NSProcessInfo processInfo] environment];
	NSString *usernameString = [dict valueForKey:@"AUTH_USERNAME"];
	NSString *hostnameString = [dict valueForKey:@"AUTH_HOSTNAME"];
	
	
	// The arguments array should contain three elements.
	// The second element is a string which we can use to determine the context in which this program was invoked.
	// This string is either a message prompting for a yes/no or a message prompting for a password.
	// We check it and supply the right response.
	NSArray *argumentsArray = [[NSProcessInfo processInfo] arguments];
	if ( [argumentsArray count] >= 2 ){		
		NSRange yesnoRange = [[argumentsArray objectAtIndex:1] rangeOfString:[NSString stringWithFormat:@"(yes/no)"]];
		
		// If the string yes/no was found in the arguments array then we need to return a YES instead of password
		if ( yesnoRange.location != NSNotFound ){
			printf("%s","YES");
			return 0;
		}
	}
	
	if ( usernameString!=nil && hostnameString!=nil ){
		// First try to get the password from the keychain
		NSString *pStr = [PasswordController passwordForHost:hostnameString user:usernameString];
		
		if ( pStr == nil ){
			// No password was found in the keychain so we should prompt the user for it.
			NSArray *promptArray = [PasswordController promptForPassword:hostnameString user:usernameString];
			NSInteger returnCode = [[promptArray objectAtIndex:1] intValue];
			NSInteger saveToKeychain = [[promptArray objectAtIndex:2] intValue];
			
			if ( returnCode == 0 ){ // Found a valid password entry
				if ( saveToKeychain == 1 ) {
					// Set the new password in the keychain. 
					[PasswordController setPassword:[promptArray objectAtIndex:0] forHost:hostnameString user:usernameString];
				}

				pStr=[promptArray objectAtIndex:0];
			} else if ( returnCode == 1 ){ // User cancelled so we'll just abort
				// We return a non zero exit code here which should cause ssh to abort (but doesn't for some reason, fix this)
				return 1;
			}
		}
		
		void *pword=(void*)[pStr UTF8String];
		printf("%s",(char*)pword);		
		[pool release];
		return 0;
	}
	
	// If we get to here something has gone wrong. Just return 1 to indicate failure
	return 1;
}