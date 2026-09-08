rule test_error:
    output:
        "done.txt"
    params:
        fail_at_sec = 20  # Set to the second at which to simulate failure, or None
    threads: esc("cpus", "test_error")
    resources:
        runtime=esc("runtime", "test_error"),
        mem_mb=esc("mem_mb", "test_error"),
        cpus_per_task=esc("cpus", "test_error"),
        slurm_partition=esc("partition", "test_error"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'test_error')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("test_error"))
    log: "log_file.txt"
    shell:
        """
        echo "Starting dummy 1-minute loop..." > {log}.{resources.attempt}
        debug "attempt={resources.attempt} fail_at_sec={params.fail_at_sec}" 2>> {log}.{resources.attempt}
        for sec in {{10..60..10}}; do
            echo "Elapsed: $sec seconds" >> {log}.{resources.attempt}
            if [ "{params.fail_at_sec}" = "$sec" ]; then
                if [ {resources.attempt} = 1 ]; then
                  echo "Simulated error at $sec seconds on attempt {resources.attempt}!" >> {log}.{resources.attempt}
                  ls --someUnknownFlag
                fi
            fi
            sleep 10
        done
        echo "Done waiting!" > {output}
        """
