#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <sqlite3.h>
#import "kern_memorystatus.h"

void deleteKeychainObjectsForGroup(NSString * group)
{

	sqlite3 *database;
	int openResult = sqlite3_open("/private/var/Keychains/keychain-2.db", &database);

	if (openResult == SQLITE_OK)
	{
		const char *deleteGenpSQL = [[NSString stringWithFormat:@"DELETE FROM genp WHERE agrp like '%%%@%%' COLLATE NOCASE;", group] UTF8String];
		const char *deleteCertSQL = [[NSString stringWithFormat:@"DELETE FROM cert WHERE agrp like '%%%@%%' COLLATE NOCASE;", group] UTF8String];
		const char *deleteKeysSQL = [[NSString stringWithFormat:@"DELETE FROM keys WHERE agrp like '%%%@%%' COLLATE NOCASE;", group] UTF8String];
		
		sqlite3_exec(database, deleteGenpSQL, NULL, NULL, NULL);

		sqlite3_exec(database, deleteCertSQL, NULL, NULL, NULL);

		sqlite3_exec(database, deleteKeysSQL, NULL, NULL, NULL);

		sqlite3_exec(database, "DELETE FROM inet;", NULL, NULL, NULL);

		sqlite3_exec(database, "DELETE FROM sqlite_sequence;", NULL, NULL, NULL);

        sqlite3_exec(database, "VACUUM;", NULL, NULL, NULL);
	
		sqlite3_close(database);
	}
}


void deleteAllKeychainObjects()
{
	sqlite3 *database;
	int openResult = sqlite3_open("/private/var/Keychains/keychain-2.db", &database);
	if (openResult == SQLITE_OK)
	{
		sqlite3_exec(database, "DELETE FROM genp WHERE agrp <> 'apple';", NULL, NULL, NULL);

		sqlite3_exec(database, "DELETE FROM cert WHERE agrp <> 'lockdown-identities';", NULL, NULL, NULL);

		sqlite3_exec(database, "DELETE FROM keys WHERE agrp <> 'lockdown-identities';", NULL, NULL, NULL);

		sqlite3_exec(database, "DELETE FROM inet;", NULL, NULL, NULL);

		sqlite3_exec(database, "DELETE FROM sqlite_sequence;", NULL, NULL, NULL);
		
        sqlite3_exec(database, "VACUUM;", NULL, NULL, NULL);
		
        sqlite3_close(database);
	}

}
int callback(void* data, int n_columns, char** col_values, char** col_names){
  NSMutableArray * results = (NSMutableArray*)data;
  for(int i = 0; i<n_columns; i++){
	NSString * string = [NSString stringWithFormat:@"%s",col_values[i]];
	if(![string hasPrefix:@"com.apple."]&&![string isEqualToString:@"apple"]&&![results containsObject:string])
	{
		[results addObject:string];
	}
  }
  return 0;
}
NSArray * getAllKeychainGroups()
{
	const char * dbPath = "/var/Keychains/keychain-2.db";

    sqlite3 *db;
	char *zErrMsg = 0;
	int rc;
    rc = sqlite3_open(dbPath, &db);
	if(rc != SQLITE_OK)
	{
		fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
		return nil;
	}

	// fprintf(stdout, "Opened database successfully\n");
	NSMutableArray * results = [[NSMutableArray alloc]init];
	rc = sqlite3_exec(db, "SELECT DISTINCT agrp FROM genp", callback, (void*)results, &zErrMsg);
	if( rc != SQLITE_OK ){
		fprintf(stderr, "SQL error: %s\n", zErrMsg);
		sqlite3_free(zErrMsg);
	}
	rc = sqlite3_exec(db, "SELECT DISTINCT agrp FROM cert", callback, (void*)results, &zErrMsg);
	if( rc != SQLITE_OK ){
		fprintf(stderr, "SQL error: %s\n", zErrMsg);
		sqlite3_free(zErrMsg);
	}
	rc = sqlite3_exec(db, "SELECT DISTINCT agrp FROM inet", callback, (void*)results, &zErrMsg);
	if( rc != SQLITE_OK ){
		fprintf(stderr, "SQL error: %s\n", zErrMsg);
		sqlite3_free(zErrMsg);
	}
	rc = sqlite3_exec(db, "SELECT DISTINCT agrp FROM keys", callback, (void*)results, &zErrMsg);
	if( rc != SQLITE_OK ){
		fprintf(stderr, "SQL error: %s\n", zErrMsg);
		sqlite3_free(zErrMsg);
	}
	
	sqlite3_close(db);
	//不用释放
	return results;
}



int main(int argc, char **argv, char **envp) {

    int rc;
    
    memorystatus_priority_properties_t props = {0, JETSAM_PRIORITY_CRITICAL};
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, getpid(), 0, &props, sizeof(props));
    if (rc < 0) { perror ("memorystatus_control"); exit(rc);}
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, getpid(), -1, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc);}
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc);}
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	
	for(int i= 0; i<arguments.count;i++)
	{
		NSString * item = arguments[i];
		if([item isEqualToString:@"-l"])
		{
			NSArray * groups = getAllKeychainGroups();
			for (NSUInteger i = 0; i < groups.count; i++) {
				printf("%s", [groups[i] UTF8String]);
				if (i < groups.count - 1) {
					printf(",");
				}
        	}		
			return 0;
		}
		if([item isEqualToString:@"-r"])
		{
			int index = i+1;
			if(index<arguments.count)
			{
				if([arguments[index] isEqualToString:@"-a"])
				{
					NSLog(@"----DELETE_ALL_KEYCHAIN_GROUPS----\n");
					deleteAllKeychainObjects();
					return 0;

				}else if([arguments[index] isEqualToString:@"-g"])
				{
					index = index+1;
					if(index<arguments.count)
					{
						NSLog(@"----DELETE:%@----\n",arguments[index]);
						deleteKeychainObjectsForGroup(arguments[index]);
						return 0;
					}
				}
			}
		}
	}
	return 0;
}


