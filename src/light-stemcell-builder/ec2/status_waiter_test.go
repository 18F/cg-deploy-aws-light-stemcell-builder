package ec2_test

import (
	"errors"
	"light-stemcell-builder/ec2"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

type emptyInfo struct{}

func (i emptyInfo) Status() string {
	return ""
}

type desiredInfo struct{}

func (i desiredInfo) Status() string {
	return "desired"
}

type undesiredInfo struct{}

func (i undesiredInfo) Status() string {
	return "undesired"
}

type statusResource struct{}

func (i statusResource) ID() string {
	return "some-resource-id"
}

var _ = Describe("StatusWaiter", func() {
	config := ec2.WaiterConfig{
		Resource:      statusResource{},
		DesiredStatus: "desired",
		PollInterval:  time.Millisecond,
		PollTimeout:   2 * time.Millisecond,
	}

	Context("when the status fetcher returns an error", func() {
		It("returns the error", func() {

			errorFetcher := func(resource ec2.StatusResource) (ec2.StatusInfo, error) {
				return emptyInfo{}, errors.New("this returns an error")
			}

			_, err := ec2.WaitForStatus(errorFetcher, config)
			Expect(err).To(MatchError("this returns an error"))
		})
	})

	Context("when the status fetcher returns the desired status", func() {
		It("returns no error", func() {
			statusFetcher := func(resource ec2.StatusResource) (ec2.StatusInfo, error) {
				return desiredInfo{}, nil
			}

			_, err := ec2.WaitForStatus(statusFetcher, config)
			Expect(err).ToNot(HaveOccurred())
		})
	})

	Context("when waiting times out", func() {
		It("returns a timeout error", func() {
			statusFetcher := func(resource ec2.StatusResource) (ec2.StatusInfo, error) {
				return undesiredInfo{}, nil
			}

			_, err := ec2.WaitForStatus(statusFetcher, config)
			Expect(err).To(MatchError("timed out after 2ms polling on resource some-resource-id"))
		})
	})

})
