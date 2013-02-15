// This file is part of the OpenTreeMap code.
//
// OpenTreeMap is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// OpenTreeMap is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with OpenTreeMap.  If not, see <http://www.gnu.org/licenses/>.

#import "OTMNearbyTreesViewController.h"
#import "OTMDistanceTableViewCell.h"
#import "OTMTreeDetailViewController.h"

#define kOTMNearbyTreesViewControllerTableViewCellReuseIdentifier @"kOTMNearbyTreesViewControllerTableViewCellReuseIdentifier"

// in meters
#define kOTMNearbyTreesViewControllerMinimumDistance 30
#define kOTMNearbyTreesViewControllerMinimumEventDistance 5

@interface OTMNearbyTreesViewController ()

@end

@implementation OTMNearbyTreesViewController

@synthesize locationManager, tableView, nearbyTrees, lastLocation, filters, segControl, nearby, pending, recent;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}


-(IBAction)updateList:(UISegmentedControl *)control {
    self.filters.listFilterType = (OTMListFilterType)control.selectedSegmentIndex;

    if (self.filters.listFilterType == kOTMFiltersShowAll) {
        self.nearbyTrees = nearby;
    } else if (self.filters.listFilterType == kOTMFiltersShowRecent) {
        self.nearbyTrees = recent;
    } else {
        self.nearbyTrees = pending;
    }

    [self.tableView reloadData];

    if (self.nearbyTrees == nil || [self.nearbyTrees count] == 0) {
        [self refreshTableWithLocation:self.lastLocation];
    }
}

//TODO: Handle unauthorized view
- (void)viewDidLoad
{
    [super viewDidLoad];

    BOOL pends = [[OTMEnvironment sharedEnvironment] pendingActive];

    if (!pends && [segControl numberOfSegments]) {
        [segControl removeSegmentAtIndex:2 animated:NO];
    }

    filters = [[OTMFilters alloc] init];
    nearby = [NSMutableArray array];
    pending = [NSMutableArray array];
    recent = [NSMutableArray array];

    if (self.locationManager == nil) {
        CLLocationManager *manager = [[CLLocationManager alloc] init];
        manager.delegate = self;
        manager.distanceFilter = kOTMNearbyTreesViewControllerMinimumEventDistance;

        self.locationManager = manager;
    }

        // Do any additional setup after loading the view.
}
- (void)viewWillAppear:(BOOL)animated {
    [pending removeAllObjects];
    [recent removeAllObjects];

    [self updateList:segControl];

    [self.locationManager startUpdatingLocation];
    [self reloadBackground];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.locationManager stopUpdatingLocation];
}

- (void)reloadBackground {
    OTMListFilterType t = (OTMListFilterType)segControl.selectedSegmentIndex;
    if (t == kOTMFiltersShowRecent || t == kOTMFiltersShowPending ||
        (t == kOTMFiltersShowAll && [self.nearby count] == 0)) {
        [self.nearbyTrees removeAllObjects];
        [self.tableView reloadData];
        [self refreshTableWithLocation:self.lastLocation];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -
#pragma mark Table Delegate and Datasource Methods

- (UITableViewCell *)tableView:(UITableView *)tblView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    OTMDistanceTableViewCell *cell = [tblView dequeueReusableCellWithIdentifier:kOTMNearbyTreesViewControllerTableViewCellReuseIdentifier];

    if (cell == nil) {
        cell = [[OTMDistanceTableViewCell alloc] initWithReuseIdentifier:kOTMNearbyTreesViewControllerTableViewCellReuseIdentifier];

    }

    NSDictionary *plot = [self.nearbyTrees objectAtIndex:[indexPath row]];
    NSDictionary *geom = [plot objectForKey:@"geometry"];
    CLLocation *treeLoc = [[CLLocation alloc] initWithLatitude:[[geom valueForKey:@"lat"] doubleValue]
                                                     longitude:[[geom valueForKey:@"lng"] doubleValue]];

    // tree variable may end up containing an NSDictionary or NSNull
    id tree = [plot objectForKey:@"tree"];

    if (tree == nil || tree == [NSNull null]) {
        cell.textLabel.text = @"Unassigned Plot";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Plot #%@",[plot objectForKey:@"id"]];
    } else {
        cell.textLabel.text = [tree objectForKey:@"species_name"];
        if (cell.textLabel.text == nil) {
            cell.textLabel.text = @"(No Species)";
        }
        if ([tree valueForKey:@"dbh"] && [tree valueForKey:@"dbh"] != @"<null>") {
            NSString *fmt = [[OTMEnvironment sharedEnvironment] dbhFormat];
            cell.detailTextLabel.text = [NSString stringWithFormat:fmt,
                                                 [[tree valueForKey:@"dbh"] doubleValue]];
        } else {
            cell.detailTextLabel.text = @"Diameter Missing";
        }

    }
    cell.thisLoc = treeLoc;
    cell.curLoc = self.lastLocation;

    return cell;
}

- (void)tableView:(UITableView *)tblView didSelectRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *plot = [self.nearbyTrees objectAtIndex:[path row]];

    [self performSegueWithIdentifier:@"pushDetails" sender:plot];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"pushDetails"]) {
        OTMTreeDetailViewController *dest = segue.destinationViewController;
        [dest view]; // Force it load its view

        NSDictionary *plot = sender;

        id keys = [[OTMEnvironment sharedEnvironment] fieldKeys];

        dest.data = [plot mutableDeepCopy];
        dest.keys = keys;
        //dest.imageView.image = self.treeImage.image;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.nearbyTrees count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(void)refreshTableWithLocation:(CLLocation *)loc {
    if (loc == nil) { loc = self.lastLocation; }

    OTMLoginManager* loginManager = [SharedAppDelegate loginManager];

    [[[OTMEnvironment sharedEnvironment] api] getPlotsNearLatitude:loc.coordinate.latitude
                   longitude:loc.coordinate.longitude
                        user:[loginManager loggedInUser]
                  maxResults:15
                     filters:filters
                    distance:1 // 1 decimal degree
                    callback:^(NSArray *json, NSError *error)
     {
         if (json) {
             [self.nearbyTrees removeAllObjects];
             [self.nearbyTrees addObjectsFromArray:[json mutableCopy]];
             [self.tableView reloadData];
         }
     }];
}

#pragma mark -
#pragma mark Core Location Delegate

-(void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)loc fromLocation:(CLLocation *)from {
    [[NSNotificationCenter defaultCenter] postNotificationName:kOTMDistaneTableViewCellRedrawDistance
                                                        object:loc];
    if (self.lastLocation == nil || [self.lastLocation distanceFromLocation:loc] > kOTMNearbyTreesViewControllerMinimumDistance) {
        self.lastLocation = loc;
        [self refreshTableWithLocation:loc];
    }
}

@end
