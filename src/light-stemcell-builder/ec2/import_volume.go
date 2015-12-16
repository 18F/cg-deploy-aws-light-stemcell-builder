package ec2

import (
	"fmt"
	"light-stemcell-builder/command"
	"reflect"
)

const (
	importVolumeRetryAttempts = 4
	taskCompletedStatus       = "completed"
)

// ImportVolume creates an EBS volume in AWS from the supplied machine imagePath
// ImportVolume assumes that the root device will be /dev/sda
func ImportVolume(aws AWS, imagePath string) (ConversionTaskInfo, error) {
	taskID, err := aws.ImportVolume(imagePath)
	if err != nil {
		return ConversionTaskInfo{}, fmt.Errorf("creating import volume task: %s", err)
	}

	for i := 0; i < importVolumeRetryAttempts; i++ {
		err = aws.ResumeImport(taskID, imagePath)
		if err == nil {
			break
		}

		if reflect.TypeOf(err) != reflect.TypeOf(command.TimeoutError{}) {
			return ConversionTaskInfo{}, fmt.Errorf("uploading machine image: %s", err)
		}
	}

	waiterConfig := WaiterConfig{
		Resource:      ConversionTaskResource{TaskID: taskID},
		DesiredStatus: taskCompletedStatus,
	}

	info, err := WaitForStatus(aws.DescribeConversionTask, waiterConfig)
	if err != nil {
		return ConversionTaskInfo{}, fmt.Errorf("getting volume id for task: %s", taskID)
	}

	if reflect.TypeOf(info) != reflect.TypeOf(ConversionTaskInfo{}) {
		return ConversionTaskInfo{}, fmt.Errorf("unexpected type returned waiting for import volume completion")
	}

	return info.(ConversionTaskInfo), nil
}
