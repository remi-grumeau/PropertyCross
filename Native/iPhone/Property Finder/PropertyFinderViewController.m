//
//  ViewController.m
//  Property Finder
//
//  Created by Colin Eberhardt on 11/10/2012.
//  Copyright (c) 2012 Colin Eberhardt. All rights reserved.
//


#import "PropertyFinderViewController.h"
#import "SearchResultsViewController.h"
#import "PropertyDataSource.h"
#import "PropertyDataSourceResult.h"
#import "PropertyUnkownLocationResult.h"
#import "PropertyLocationsResult.h"
#import "JSONFIleDataSource.h"
#import "JSONWebDataSource.h"
#import "LocationsTableViewSource.h"
#import "RecentSearchesTableViewSource.h"
#import "AppDelegate.h"
#import "RecentSearchDataEntity.h"
#import "SearchItemBase.h"
#import "PlainTextSearchItem.h"
#import "GeolocationSearchItem.h"
#import "FavouritesViewController.h"
#import "PersistentDataStore.h"

@interface PropertyFinderViewController ()

@end

@implementation PropertyFinderViewController
{
    PropertyDataSource* _dataSource;
    TableViewDataSourceBase*_tableViewSource;
    SearchItemBase* _searchItem;
    CLLocationManager* _locationManager;
    BOOL _awaitingLocation;
    PersistentDataStore* _dataStore;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        JSONWebDataSource* dataSource = [[JSONWebDataSource alloc] init];
        _dataSource = [[PropertyDataSource alloc] initWithDataSource:dataSource];
        
        self.title = @"Property Finder";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _awaitingLocation = NO;
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _dataStore = appDelegate.persistentDataStore;
    
    [self showRecentSearches];
    
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Search"
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:nil];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Favs"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(favouriteButtonTouched)];
    self.loadingIndicator.hidden = YES;

    [self.searchText addTarget:self
                        action:@selector(searchTextDidChange:)
              forControlEvents:UIControlEventEditingChanged];
}

- (void) searchTextDidChange: (id)sender
{
    _searchItem = [PlainTextSearchItem plainTextSearchItemFromString:self.searchText.text];
}

- (void) favouriteButtonTouched
{
    FavouritesViewController* controller = [[FavouritesViewController alloc] initWithNibName:@"FavouritesViewController" bundle:nil];
    
    [self.navigationController pushViewController:controller
                                         animated:YES];
}

-(void)backButtonPressed
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) itemSelected: (NSObject*) item
{
    if ([item isKindOfClass:[Location class]])
    {   
        Location* location = (Location*)item;
        _searchItem = [PlainTextSearchItem plainTextSearchItemFromLocation:location];
    }
    else if ([item isKindOfClass:[RecentSearchDataEntity class]])
    {
        RecentSearchDataEntity* recentSearch = (RecentSearchDataEntity*)item;
        _searchItem = [SearchItemBase fromRecentSearchDataEntity:recentSearch];
    }
    
    self.searchText.text = _searchItem.displayText;
    [self executeSearch];
}

- (IBAction)goButtonTouched:(id)sender
{
    [self.searchText resignFirstResponder];
    [self executeSearch];
}

- (void) executeSearch
{
    self.userMessageLabel.text = nil;
    
    PropertyDataSourceResultSuccess success = ^(PropertyDataSourceResult *result){
        
        // stop the loading indicator
        self.loadingIndicator.hidden = YES;
        [self.loadingIndicator stopAnimating];
        
        // determine the type of returned result
        if ([result isKindOfClass:[PropertyListingResult class]])
        {
            // if properties were returned navigate to the results view controller
            SearchResultsViewController* controller = [[SearchResultsViewController alloc] initWithNibName:@"SearchResultsViewController" bundle:nil];
            [controller setResult:(PropertyListingResult*)result];
            
            [self.navigationController pushViewController:controller
                                                 animated:YES];
            
            [_dataStore addToRecentSearches:_searchItem];
            [self showRecentSearches];
            
        }
        else if ([result isKindOfClass:[PropertyLocationsResult class]])
        {
            // display a list of suggested locations
            _tableViewSource = [LocationsTableViewSource locationsTableViewSourceFromArray:[(PropertyLocationsResult*)result locations]];
            [_tableViewSource attachToTableView:self.tableView];
            _tableViewSource.delegate = self;
        }
        else if ([result isKindOfClass:[PropertyUnkownLocationResult class]])
        {
            self.userMessageLabel.text = @"The location given was not recognised.";
            
            // hide the locations / recent searches table
            self.tableView.dataSource = nil;
            [self.tableView reloadData];
        }
    };
    
    self.loadingIndicator.hidden = NO;
    [self.loadingIndicator startAnimating];
    
    [_searchItem findPropertiesWithDataSource:_dataSource
                                       result:success];
}

- (void) showRecentSearches
{
    if (_dataStore.recentSearches.count > 0)
    {
        // display the recent searches
        _tableViewSource = [RecentSearchesTableViewSource recentSearchesTableViewSourceFromArray:_dataStore.recentSearches];
        [_tableViewSource attachToTableView:self.tableView];
        _tableViewSource.delegate = self;
    }
}


- (IBAction)myLocationButtonTouched:(id)sender
{
    [_locationManager startUpdatingLocation];
    _awaitingLocation = YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    if (_awaitingLocation)
    {
        CLLocation* location = locations[0];
        _searchItem = [GeolocationSearchItem geolocationSearchItemFromLocation:location.coordinate];
        self.searchText.text = _searchItem.displayText;
        [_locationManager stopUpdatingLocation];
        
        [self executeSearch];
    }
}
@end