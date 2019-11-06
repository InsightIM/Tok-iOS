// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

@interface OCTFileTools : NSObject

/**
 * Creates filePath in directory for given fileName. In case if file already exists appends " N" suffix,
 * e.g. "file 2.txt", "file 3.txt".
 *
 * @param directory Directory part of filePath.
 * @param fileName Name of the file to use in path.
 *
 * @return File path to file that does not exist.
 */
+ (nonnull NSString *)createNewFilePathInDirectory:(nonnull NSString *)directory fileName:(nonnull NSString *)fileName;

@end
